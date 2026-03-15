#!/usr/bin/env python3
from __future__ import annotations

import copy
from contextlib import asynccontextmanager
import datetime as dt
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import tempfile
import threading
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uvicorn


HOST = os.environ.get("LAB_GUI_HOST", "127.0.0.1")
PORT = int(os.environ.get("LAB_GUI_PORT", "8088"))
REPO_ROOT = pathlib.Path(os.environ.get("LAB_GUI_REPO_ROOT", ".")).resolve()
STATE_DIR = pathlib.Path(os.environ.get("LAB_GUI_STATE_DIR", REPO_ROOT / ".lab-gui")).resolve()
INSTANCE_CONFIG_PATH = pathlib.Path(
    os.environ.get("LAB_GUI_INSTANCE_CONFIG", REPO_ROOT / "config" / "instance.json")
).resolve()
EXPORT_NIX = pathlib.Path(
    os.environ.get("LAB_GUI_EXPORT_NIX", REPO_ROOT / "scripts" / "gui" / "export-source-config.nix")
).resolve()
VALIDATE_NIX = pathlib.Path(
    os.environ.get("LAB_GUI_VALIDATE_NIX", REPO_ROOT / "scripts" / "gui" / "validate-instance.nix")
).resolve()
TEMPLATE_DIR = pathlib.Path(
    os.environ.get("LAB_GUI_TEMPLATE_DIR", REPO_ROOT / "scripts" / "gui" / "templates")
).resolve()
STATIC_DIR = pathlib.Path(
    os.environ.get("LAB_GUI_STATIC_DIR", REPO_ROOT / "scripts" / "gui" / "static")
).resolve()
BACKUPS_DIR = STATE_DIR / "backups"
JOBS_DIR = STATE_DIR / "jobs"
JOBS_INDEX_PATH = JOBS_DIR / "index.json"

CORE_USERS = ["admin", "teacher", "student"]
HOSTNAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
JOB_LOCK = threading.Lock()

SOFTWARE_PRESET_OPTIONS = [
    {
        "id": "base-cli",
        "label": "Base CLI",
        "description": "Core shell, git, search, and admin command-line tools."
    },
    {
        "id": "desktop",
        "label": "Desktop",
        "description": "GNOME-facing apps such as Ghostty, Chromium, VS Code, and shell extensions."
    },
    {
        "id": "dev-tools",
        "label": "Dev Tools",
        "description": "Compiler, tmux, tig, and lab coding helpers."
    },
    {
        "id": "container",
        "label": "Containers",
        "description": "Docker runtime plus docker-compose tooling."
    },
    {
        "id": "network-admin",
        "label": "Network Admin",
        "description": "PXE and network support tooling such as dnsmasq."
    },
    {
        "id": "publishing",
        "label": "Publishing",
        "description": "Image, PDF, TeX, and diagram tooling."
    },
    {
        "id": "python",
        "label": "Python",
        "description": "Python interpreter plus common training helpers."
    },
    {
        "id": "lua",
        "label": "Lua",
        "description": "Lua language server and luarocks."
    },
    {
        "id": "java",
        "label": "Java",
        "description": "JDK and Maven."
    },
    {
        "id": "node",
        "label": "Node",
        "description": "Node.js runtime."
    },
    {
        "id": "php",
        "label": "PHP",
        "description": "PHP CLI runtime."
    },
    {
        "id": "browser",
        "label": "Firefox",
        "description": "Enable Firefox in addition to Chromium."
    },
    {
        "id": "editor",
        "label": "Neovim",
        "description": "Enable Neovim as an additional editor."
    }
]

VSCODE_PRESET_OPTIONS = [
    {
        "id": "web",
        "label": "Web",
        "description": "Live Server and baseline web workflow."
    },
    {
        "id": "java",
        "label": "Java",
        "description": "Java extension pack, debugger, tests, and Maven tooling."
    }
]

FEATURE_OPTIONS = [
    {
        "id": "binaryCache",
        "label": "Binary Cache",
        "description": "Use the controller cache for lab host builds and installs."
    },
    {
        "id": "homeReset",
        "label": "Home Reset",
        "description": "Reset the student home on each boot and keep snapshots."
    },
    {
        "id": "screensaver",
        "label": "Screensaver",
        "description": "Enable the local text-mode screensaver workflow."
    },
    {
        "id": "veyon",
        "label": "Veyon",
        "description": "Enable classroom monitoring and control support."
    },
    {
        "id": "guiBackend",
        "label": "GUI Backend",
        "description": "Run the controller-local management backend."
    }
]

BUILD_TARGET_OPTIONS = [
    {
        "id": "validate",
        "label": "Validate",
        "description": "Checks plus controller and first three clients."
    },
    {
        "id": "controller",
        "label": "Build Controller",
        "description": "Build only the controller system closure."
    },
    {
        "id": "clients-smoke",
        "label": "Build Clients Smoke",
        "description": "Build the first three client closures."
    },
    {
        "id": "netboot",
        "label": "Build Netboot",
        "description": "Build kernel, ramdisk, and iPXE artifacts."
    }
]

DEPLOY_TARGET_OPTIONS = [
    {
        "id": "controller",
        "label": "Deploy Controller",
        "description": "Run nixos-rebuild switch on the controller."
    },
    {
        "id": "host",
        "label": "Deploy One Host",
        "description": "Run Colmena for a single client."
    },
    {
        "id": "all",
        "label": "Deploy All",
        "description": "Run Colmena across the full lab tag."
    }
]

@asynccontextmanager
async def lifespan(_app: FastAPI):
    ensure_directories()
    yield


app = FastAPI(title="Lab GUI Backend", version="0.2.0", lifespan=lifespan)
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))
if STATIC_DIR.exists():
    app.mount("/ui/static", StaticFiles(directory=str(STATIC_DIR)), name="ui-static")


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def ensure_directory_permissions(path: pathlib.Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    try:
        os.chown(path, -1, path.parent.stat().st_gid)
    except PermissionError:
        pass
    try:
        os.chmod(path, 0o2770)
    except PermissionError:
        pass


def apply_file_permissions(path: pathlib.Path, mode: int = 0o640) -> None:
    try:
        os.chown(path, -1, path.parent.stat().st_gid)
    except PermissionError:
        pass
    try:
        os.chmod(path, mode)
    except PermissionError:
        pass


def ensure_directories() -> None:
    ensure_directory_permissions(STATE_DIR)
    ensure_directory_permissions(BACKUPS_DIR)
    ensure_directory_permissions(JOBS_DIR)
    if not JOBS_INDEX_PATH.exists():
        write_json_atomic(JOBS_INDEX_PATH, [])


def write_json_atomic(path: pathlib.Path, payload: object) -> None:
    ensure_directory_permissions(path.parent)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temp_path = pathlib.Path(handle.name)
    temp_path.replace(path)
    apply_file_permissions(path)


def read_json(path: pathlib.Path, default: object) -> object:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def nix_eval_json(
    nix_file: pathlib.Path,
    argstrs: dict[str, str] | None = None,
    extra_env: dict[str, str] | None = None
) -> object:
    command = [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "eval",
        "--impure",
        "--json",
        "--file",
        str(nix_file)
    ]
    for name, value in (argstrs or {}).items():
        command.extend(["--argstr", name, value])

    result = subprocess.run(
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env={**os.environ, **(extra_env or {})},
        check=False
    )
    if result.returncode != 0:
        raise HTTPException(status_code=400, detail=result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout)


def load_effective_config() -> dict:
    if INSTANCE_CONFIG_PATH.exists():
        return read_json(INSTANCE_CONFIG_PATH, {})
    return nix_eval_json(EXPORT_NIX)


def config_source_info() -> dict[str, object]:
    return {
        "usingInstanceConfig": INSTANCE_CONFIG_PATH.exists(),
        "instanceConfigPath": str(INSTANCE_CONFIG_PATH),
        "repoRoot": str(REPO_ROOT)
    }


def require_mapping(value: object, label: str) -> dict:
    if not isinstance(value, dict):
        raise HTTPException(status_code=400, detail=f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list:
    if not isinstance(value, list):
        raise HTTPException(status_code=400, detail=f"{label} must be a list")
    return value


def require_nonempty_string(value: object, label: str) -> str:
    if not isinstance(value, str) or value.strip() == "":
        raise HTTPException(status_code=400, detail=f"{label} must be a non-empty string")
    return value.strip()


def hash_password(password: str) -> str:
    result = subprocess.run(
        ["openssl", "passwd", "-6", "-stdin"],
        input=password,
        text=True,
        capture_output=True,
        check=False
    )
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr.strip() or "password hashing failed")
    return result.stdout.strip()


def existing_extra_user_hashes(existing_config: dict) -> dict[str, str]:
    extra_users = existing_config.get("users", {}).get("extraUsers", [])
    return {
        user.get("name"): user.get("passwordHash")
        for user in extra_users
        if isinstance(user, dict) and isinstance(user.get("name"), str)
    }


def apply_password(user: dict, label: str, fallback_hash: str | None = None) -> None:
    password = user.pop("password", None)
    if isinstance(password, str) and password != "":
        user["passwordHash"] = hash_password(password)
        return
    if isinstance(user.get("passwordHash"), str) and user["passwordHash"] != "":
        return
    if fallback_hash:
        user["passwordHash"] = fallback_hash
        return
    raise HTTPException(status_code=400, detail=f"{label}.password or {label}.passwordHash is required")


def canonicalize_config(payload: object, existing_config: dict) -> dict:
    config = require_mapping(copy.deepcopy(payload), "config")
    config.setdefault("schemaVersion", 1)

    for section_name in ["network", "hosts", "users", "software", "features", "org", "locale"]:
        require_mapping(config.get(section_name), section_name)

    users = config["users"]
    existing_users = existing_config.get("users", {})

    for role in CORE_USERS:
        user = require_mapping(users.get(role), f"users.{role}")
        require_nonempty_string(user.get("name"), f"users.{role}.name")
        apply_password(user, f"users.{role}", existing_users.get(role, {}).get("passwordHash"))

    extra_users = require_list(users.get("extraUsers", []), "users.extraUsers")
    fallback_hashes = existing_extra_user_hashes(existing_config)
    for index, user in enumerate(extra_users):
        extra_user = require_mapping(user, f"users.extraUsers[{index}]")
        name = require_nonempty_string(extra_user.get("name"), f"users.extraUsers[{index}].name")
        apply_password(extra_user, f"users.extraUsers[{index}]", fallback_hashes.get(name))

    hosts = config["hosts"]
    clients = require_mapping(hosts.get("clients"), "hosts.clients")
    naming = require_mapping(clients.get("naming"), "hosts.clients.naming")
    require_nonempty_string(naming.get("prefix"), "hosts.clients.naming.prefix")
    require_nonempty_string(config["network"].get("masterDhcpIp"), "network.masterDhcpIp")
    require_nonempty_string(config["network"].get("networkBase"), "network.networkBase")
    require_nonempty_string(config["network"].get("ifaceName"), "network.ifaceName")

    return config


def validate_candidate(config: dict) -> dict:
    ensure_directories()
    with tempfile.NamedTemporaryFile("w", dir=STATE_DIR, delete=False, encoding="utf-8", suffix=".json") as handle:
        json.dump(config, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temp_path = pathlib.Path(handle.name)

    try:
        validated = nix_eval_json(
            VALIDATE_NIX,
            extra_env={"LAB_GUI_VALIDATE_CONFIG_PATH": str(temp_path)}
        )
    finally:
        temp_path.unlink(missing_ok=True)

    return require_mapping(validated, "validatedConfig")


def write_instance_config(config: dict) -> None:
    ensure_directories()
    if INSTANCE_CONFIG_PATH.exists():
        backup_name = f"instance-{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        backup_path = BACKUPS_DIR / backup_name
        shutil.copy2(INSTANCE_CONFIG_PATH, backup_path)
        apply_file_permissions(backup_path)
    write_json_atomic(INSTANCE_CONFIG_PATH, config)


def load_jobs() -> list[dict]:
    ensure_directories()
    return require_list(read_json(JOBS_INDEX_PATH, []), "jobs")


def save_jobs(jobs: list[dict]) -> None:
    write_json_atomic(JOBS_INDEX_PATH, jobs)


def update_job(job_id: str, **changes: object) -> dict:
    with JOB_LOCK:
        jobs = load_jobs()
        for job in jobs:
            if job["id"] == job_id:
                job.update(changes)
                save_jobs(jobs)
                return job
    raise HTTPException(status_code=404, detail=f"job {job_id} not found")


def log_path_for(job_id: str) -> pathlib.Path:
    ensure_directories()
    return JOBS_DIR / f"{job_id}.log"


def client_host_names(config: dict, limit: int | None = None) -> list[str]:
    clients = config["hosts"]["clients"]
    count = int(clients["count"])
    prefix = clients["naming"]["prefix"]
    pad_to = int(clients["naming"]["padTo"])
    names = [f"{prefix}{number:0{pad_to}d}" for number in range(1, count + 1)]
    return names if limit is None else names[:limit]


def controller_host_name(config: dict) -> str:
    return require_nonempty_string(config["hosts"]["controller"]["name"], "hosts.controller.name")


def validate_host_name(config: dict, host_name: str) -> str:
    require_nonempty_string(host_name, "host")
    if HOSTNAME_PATTERN.match(host_name) is None:
        raise HTTPException(status_code=400, detail="host must match [a-z0-9_-]+")
    allowed_hosts = set(client_host_names(config))
    if host_name not in allowed_hosts:
        raise HTTPException(status_code=400, detail=f"unknown host '{host_name}'")
    return host_name


def validate_command(config: dict) -> list[str]:
    command = [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "build",
        ".#checks.x86_64-linux.normalize-config",
        ".#checks.x86_64-linux.validate-extra-users"
    ]
    for host_name in client_host_names(config, limit=3):
        command.append(f".#nixosConfigurations.{host_name}.config.system.build.toplevel")
    command.append(f".#nixosConfigurations.{controller_host_name(config)}.config.system.build.toplevel")
    command.append("--no-write-lock-file")
    return command


def build_command(config: dict, target: str) -> list[str]:
    base_command = [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "build"
    ]
    if target == "controller":
        return base_command + [
            f".#nixosConfigurations.{controller_host_name(config)}.config.system.build.toplevel",
            "--no-write-lock-file"
        ]
    if target == "clients-smoke":
        return base_command + [
            *[f".#nixosConfigurations.{host}.config.system.build.toplevel" for host in client_host_names(config, limit=3)],
            "--no-write-lock-file"
        ]
    if target == "netboot":
        return base_command + [
            ".#nixosConfigurations.netboot.config.system.build.kernel",
            ".#nixosConfigurations.netboot.config.system.build.netbootRamdisk",
            ".#nixosConfigurations.netboot.config.system.build.netbootIpxeScript",
            "--no-write-lock-file"
        ]
    if target == "validate":
        return validate_command(config)
    raise HTTPException(status_code=400, detail=f"unsupported build target '{target}'")


def deploy_command(config: dict, target: str, host: str | None = None) -> list[str]:
    if target == "controller":
        return [
            "/run/current-system/sw/bin/nixos-rebuild",
            "switch",
            "--flake",
            f".#{controller_host_name(config)}",
            "--no-write-lock-file"
        ]
    if target == "all":
        return ["colmena", "apply", "--impure", "--on", "@lab"]
    if target == "host":
        validated_host = validate_host_name(config, host or "")
        return ["colmena", "apply", "--impure", "--on", validated_host]
    raise HTTPException(status_code=400, detail=f"unsupported deploy target '{target}'")


def run_job(job_id: str, command: list[str]) -> None:
    log_path = log_path_for(job_id)
    update_job(job_id, status="running", startedAt=now_iso(), command=command)

    try:
        with log_path.open("w", encoding="utf-8") as handle:
            handle.write(f"$ {shlex.join(command)}\n\n")
            process = subprocess.Popen(
                command,
                cwd=REPO_ROOT,
                stdout=handle,
                stderr=subprocess.STDOUT,
                text=True
            )
            return_code = process.wait()
        apply_file_permissions(log_path)
    except Exception as exc:
        if log_path.exists():
            apply_file_permissions(log_path)
        update_job(
            job_id,
            status="failed",
            finishedAt=now_iso(),
            returnCode=-1,
            error=str(exc)
        )
        return

    update_job(
        job_id,
        status="succeeded" if return_code == 0 else "failed",
        finishedAt=now_iso(),
        returnCode=return_code
    )


def start_job(kind: str, command: list[str]) -> dict:
    ensure_directories()
    with JOB_LOCK:
        jobs = load_jobs()
        running_job = next((job for job in jobs if job["status"] == "running"), None)
        if running_job is not None:
            raise HTTPException(status_code=409, detail=f"job {running_job['id']} is already running")

        job_id = uuid.uuid4().hex
        job = {
            "id": job_id,
            "kind": kind,
            "status": "queued",
            "createdAt": now_iso(),
            "command": command
        }
        jobs.insert(0, job)
        save_jobs(jobs)

    thread = threading.Thread(target=run_job, args=(job_id, command), daemon=True)
    thread.start()
    return job


def frontend_options() -> dict[str, object]:
    return {
        "softwarePresets": SOFTWARE_PRESET_OPTIONS,
        "vscodePresets": VSCODE_PRESET_OPTIONS,
        "featureOptions": FEATURE_OPTIONS,
        "buildTargets": BUILD_TARGET_OPTIONS,
        "deployTargets": DEPLOY_TARGET_OPTIONS
    }


def status_snapshot(config: dict | None = None, jobs: list[dict] | None = None) -> dict[str, object]:
    effective_config = load_effective_config() if config is None else config
    job_list = load_jobs() if jobs is None else jobs
    return {
        "configSource": config_source_info(),
        "controller": effective_config["hosts"]["controller"]["name"],
        "sampleClients": client_host_names(effective_config, limit=3),
        "runningJob": next((job for job in job_list if job["status"] == "running"), None)
    }


def bootstrap_payload() -> dict[str, object]:
    config = load_effective_config()
    jobs = load_jobs()
    return {
        "config": config,
        "jobs": jobs,
        "status": status_snapshot(config, jobs),
        "options": frontend_options()
    }


@app.get("/", response_class=HTMLResponse)
@app.get("/ui", response_class=HTMLResponse)
def root(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "request": request,
            "bootstrap": bootstrap_payload()
        }
    )


@app.get("/api/status")
def api_status() -> dict:
    return status_snapshot()


@app.get("/api/options")
def api_options() -> dict:
    return frontend_options()


@app.get("/api/config")
def get_config() -> dict:
    return load_effective_config()


@app.get("/api/config/source")
def get_config_source() -> dict:
    return config_source_info()


@app.post("/api/config")
def save_config(payload: dict) -> dict:
    existing_config = load_effective_config()
    candidate_config = canonicalize_config(payload, existing_config)
    validated_config = validate_candidate(candidate_config)
    write_instance_config(validated_config)
    return {
        "saved": True,
        "configPath": str(INSTANCE_CONFIG_PATH),
        "config": validated_config
    }


@app.post("/api/validate")
def queue_validate() -> dict:
    config = load_effective_config()
    return start_job("validate", validate_command(config))


@app.post("/api/build")
def queue_build(payload: dict) -> dict:
    target = require_nonempty_string(payload.get("target"), "target")
    config = load_effective_config()
    return start_job(f"build:{target}", build_command(config, target))


@app.post("/api/deploy")
def queue_deploy(payload: dict) -> dict:
    target = require_nonempty_string(payload.get("target"), "target")
    host = payload.get("host")
    config = load_effective_config()
    return start_job(f"deploy:{target}", deploy_command(config, target, host))


@app.get("/api/jobs")
def list_jobs() -> list[dict]:
    return load_jobs()


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str) -> dict:
    for job in load_jobs():
        if job["id"] == job_id:
            return job
    raise HTTPException(status_code=404, detail=f"job {job_id} not found")


@app.get("/api/jobs/{job_id}/log", response_class=PlainTextResponse)
def get_job_log(job_id: str) -> str:
    log_path = log_path_for(job_id)
    if not log_path.exists():
        raise HTTPException(status_code=404, detail=f"log for job {job_id} not found")
    return log_path.read_text(encoding="utf-8")


if __name__ == "__main__":
    ensure_directories()
    uvicorn.run(app, host=HOST, port=PORT)
