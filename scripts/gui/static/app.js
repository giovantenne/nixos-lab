(function () {
  const bootstrapNode = document.getElementById("lab-gui-bootstrap");
  const bootstrap = JSON.parse(bootstrapNode.textContent);

  const state = {
    config: bootstrap.config,
    jobs: bootstrap.jobs,
    status: bootstrap.status,
    options: bootstrap.options,
    selectedJobId: bootstrap.jobs.length > 0 ? bootstrap.jobs[0].id : null,
    refreshTimer: null
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#39;");
  }

  function splitListInput(raw) {
    return raw
      .split(/\r?\n|,/)
      .map((entry) => entry.trim())
      .filter(Boolean);
  }

  function joinListInput(values) {
    return (values || []).join("\n");
  }

  async function requestJson(url, options) {
    const response = await fetch(url, {
      headers: {
        "Content-Type": "application/json"
      },
      ...options
    });

    if (!response.ok) {
      let detail = `${response.status} ${response.statusText}`;
      try {
        const payload = await response.json();
        detail = payload.detail || detail;
      } catch (_error) {
        const text = await response.text();
        if (text) {
          detail = text;
        }
      }
      throw new Error(detail);
    }

    if (response.status === 204) {
      return null;
    }
    return response.json();
  }

  function showFlash(message, tone) {
    const flashArea = byId("flash-area");
    const node = document.createElement("div");
    node.className = `flash ${tone}`;
    node.textContent = message;
    flashArea.prepend(node);
    window.setTimeout(() => node.remove(), 7000);
  }

  function statusChipMarkup(label, active) {
    return `
      <span class="status-chip">${escapeHtml(label)}${active ? "" : " (disabled)"}</span>
    `;
  }

  function renderStatus() {
    const source = state.status.configSource.usingInstanceConfig ? "instance.json" : "lab-config.nix";
    byId("config-source-label").textContent = source;
    byId("config-source-chip").textContent = state.status.configSource.usingInstanceConfig ? "GUI-owned" : "Fallback";
    byId("controller-name").textContent = state.status.controller;
    byId("sample-clients").textContent = state.status.sampleClients.join(", ");
  }

  function renderCoreUsers() {
    const container = byId("core-users-grid");
    const users = state.config.users;
    const cards = [
      {
        id: "admin",
        title: "Admin",
        description: "Sudo, SSH, deploy access, and controller ownership.",
        extraMarkup: `
          <label>
            <span>SSH Public Keys (one per line)</span>
            <textarea id="user-admin-ssh-keys" rows="4">${escapeHtml(joinListInput(users.admin.sshKeys || []))}</textarea>
          </label>
        `
      },
      {
        id: "teacher",
        title: "Teacher",
        description: "Classroom operator with Veyon-related permissions.",
        extraMarkup: ""
      },
      {
        id: "student",
        title: "Student",
        description: "Client autologin and home-reset account.",
        extraMarkup: `
          <div class="inline-fields compact">
            <label>
              <span>Autologin on Clients</span>
              <input id="user-student-autologin" type="checkbox" ${users.student.autologinOnClients ? "checked" : ""}>
            </label>
            <label>
              <span>Reset Home</span>
              <input id="user-student-reset-home" type="checkbox" ${users.student.resetHome ? "checked" : ""}>
            </label>
          </div>
        `
      }
    ];

    container.innerHTML = cards.map((card) => `
      <article class="sub-card">
        <div class="section-title-row">
          <div>
            <h4>${escapeHtml(card.title)}</h4>
            <p>${escapeHtml(card.description)}</p>
          </div>
          ${statusChipMarkup(card.title, true)}
        </div>
        <label>
          <span>Username</span>
          <input id="user-${card.id}-name" type="text" value="${escapeHtml(users[card.id].name)}">
        </label>
        <label>
          <span>New Password</span>
          <input id="user-${card.id}-password" type="password" placeholder="Leave blank to keep current password">
        </label>
        ${card.extraMarkup}
      </article>
    `).join("");
  }

  function extraUserRowMarkup(user, index) {
    const groups = joinListInput(user.extraGroups || []).replaceAll("\n", ", ");
    return `
      <article class="extra-user-card" data-index="${index}" data-password-hash="${escapeHtml(user.passwordHash || "")}">
        <div class="section-title-row">
          <div>
            <h4>Extra User ${index + 1}</h4>
            <p>Standard account present on all machines.</p>
          </div>
          <button class="ghost-button remove-extra-user" type="button">Remove</button>
        </div>
        <div class="details-grid">
          <label>
            <span>Username</span>
            <input class="extra-user-name" type="text" value="${escapeHtml(user.name || "")}">
          </label>
          <label>
            <span>Description</span>
            <input class="extra-user-description" type="text" value="${escapeHtml(user.description || "")}">
          </label>
          <label>
            <span>Groups (comma or newline separated)</span>
            <textarea class="extra-user-groups" rows="3">${escapeHtml(groups)}</textarea>
          </label>
          <label>
            <span>SSH Keys (one per line)</span>
            <textarea class="extra-user-ssh-keys" rows="3">${escapeHtml(joinListInput(user.sshKeys || []))}</textarea>
          </label>
          <label>
            <span>New Password</span>
            <input class="extra-user-password" type="password" placeholder="${user.passwordHash ? "Leave blank to keep current password" : "Required for new user"}">
          </label>
        </div>
      </article>
    `;
  }

  function bindExtraUserActions() {
    document.querySelectorAll(".remove-extra-user").forEach((button) => {
      button.addEventListener("click", () => {
        button.closest(".extra-user-card").remove();
      });
    });
  }

  function renderExtraUsers() {
    const container = byId("extra-users-list");
    const users = state.config.users.extraUsers || [];
    if (users.length === 0) {
      container.innerHTML = '<div class="empty-state">No extra users yet. Add one when you need a standard local account.</div>';
      return;
    }
    container.innerHTML = users.map((user, index) => extraUserRowMarkup(user, index)).join("");
    bindExtraUserActions();
  }

  function renderOptionGroup(containerId, options, selectedIds) {
    const selected = new Set(selectedIds || []);
    const container = byId(containerId);
    container.innerHTML = options.map((option) => `
      <article class="option-card">
        <label>
          <input data-option-id="${escapeHtml(option.id)}" type="checkbox" ${selected.has(option.id) ? "checked" : ""}>
          <span class="option-meta">
            <strong>${escapeHtml(option.label)}</strong>
            <span>${escapeHtml(option.description)}</span>
          </span>
        </label>
      </article>
    `).join("");
  }

  function renderSoftware() {
    renderOptionGroup("software-presets-grid", state.options.softwarePresets, state.config.software.presets);
    renderOptionGroup("software-controller-grid", state.options.softwarePresets, state.config.software.hostScopes.controller);
    renderOptionGroup("software-client-grid", state.options.softwarePresets, state.config.software.hostScopes.clients);
    renderOptionGroup("student-vscode-grid", state.options.vscodePresets, state.config.software.vscode.studentPresets);
    renderOptionGroup("admin-vscode-grid", state.options.vscodePresets, state.config.software.vscode.adminPresets);

    byId("software-extra-packages").value = joinListInput(state.config.software.extraPackages || []);
    byId("software-student-favorites").value = joinListInput(state.config.software.desktop.studentFavorites || []);
    byId("software-staff-favorites").value = joinListInput(state.config.software.desktop.staffFavorites || []);
  }

  function renderFeatures() {
    const container = byId("feature-grid");
    container.innerHTML = state.options.featureOptions.map((feature) => {
      const configEntry = state.config.features[feature.id];
      const enabled = typeof configEntry === "object" ? configEntry.enable : configEntry;
      return `
        <article class="feature-card">
          <label>
            <input data-feature-id="${escapeHtml(feature.id)}" type="checkbox" ${enabled ? "checked" : ""}>
            <span class="feature-meta">
              <strong>${escapeHtml(feature.label)}</strong>
              <span>${escapeHtml(feature.description)}</span>
            </span>
          </label>
        </article>
      `;
    }).join("");

    byId("gui-backend-port").value = state.config.features.guiBackend.port;
  }

  function renderAdvancedFields() {
    byId("network-master-dhcp-ip").value = state.config.network.masterDhcpIp;
    byId("network-base").value = state.config.network.networkBase;
    byId("network-master-host-number").value = state.config.network.masterHostNumber;
    byId("network-iface-name").value = state.config.network.ifaceName;
    byId("controller-host-name").value = state.config.hosts.controller.name;
    byId("clients-count").value = state.config.hosts.clients.count;
    byId("clients-prefix").value = state.config.hosts.clients.naming.prefix;
    byId("clients-pad-to").value = state.config.hosts.clients.naming.padTo;

    byId("org-homepage-url").value = state.config.org.homepageUrl;
    byId("org-student-git-name").value = state.config.org.git.student.name;
    byId("org-student-git-email").value = state.config.org.git.student.email;
    byId("org-admin-git-name").value = state.config.org.git.admin.name;
    byId("org-admin-git-email").value = state.config.org.git.admin.email;

    byId("locale-time-zone").value = state.config.locale.timeZone;
    byId("locale-default-locale").value = state.config.locale.defaultLocale;
    byId("locale-extra-locale").value = state.config.locale.extraLocale;
    byId("locale-keyboard-layout").value = state.config.locale.keyboardLayout;
    byId("locale-console-keymap").value = state.config.locale.consoleKeyMap;
  }

  function renderBuildActions() {
    const container = byId("build-actions");
    container.innerHTML = state.options.buildTargets.map((target) => `
      <button class="ghost-button build-target" data-build-target="${escapeHtml(target.id)}" type="button">
        ${escapeHtml(target.label)}
      </button>
    `).join("");

    container.querySelectorAll(".build-target").forEach((button) => {
      button.addEventListener("click", () => queueBuild(button.dataset.buildTarget));
    });
  }

  function renderDeployHostOptions() {
    const select = byId("deploy-host-select");
    const hosts = buildClientHostNames();
    select.innerHTML = hosts.map((host) => `
      <option value="${escapeHtml(host)}">${escapeHtml(host)}</option>
    `).join("");
  }

  function buildClientHostNames() {
    const count = Number(state.config.hosts.clients.count);
    const prefix = state.config.hosts.clients.naming.prefix;
    const padTo = Number(state.config.hosts.clients.naming.padTo);
    const hosts = [];
    for (let number = 1; number <= count; number += 1) {
      hosts.push(`${prefix}${String(number).padStart(padTo, "0")}`);
    }
    return hosts;
  }

  function renderJobs() {
    const container = byId("jobs-list");
    if (state.jobs.length === 0) {
      container.innerHTML = '<div class="empty-state">No queued or completed jobs yet.</div>';
      return;
    }

    container.innerHTML = state.jobs.map((job) => `
      <button class="job-card ${state.selectedJobId === job.id ? "active" : ""}" data-job-id="${escapeHtml(job.id)}" type="button">
        <div class="job-head">
          <strong>${escapeHtml(job.kind)}</strong>
          <span class="job-status ${escapeHtml(job.status)}">${escapeHtml(job.status)}</span>
        </div>
        <div class="job-meta">
          <span>${escapeHtml(job.createdAt)}</span>
          <span>${job.returnCode === undefined ? "" : `exit ${job.returnCode}`}</span>
        </div>
      </button>
    `).join("");

    container.querySelectorAll(".job-card").forEach((button) => {
      button.addEventListener("click", async () => {
        state.selectedJobId = button.dataset.jobId;
        renderJobs();
        await refreshSelectedLog();
      });
    });
  }

  async function refreshSelectedLog() {
    const logNode = byId("job-log");
    if (!state.selectedJobId) {
      logNode.textContent = "Select a job to inspect its log.";
      return;
    }

    try {
      const response = await fetch(`/api/jobs/${state.selectedJobId}/log`);
      if (!response.ok) {
        logNode.textContent = `No log available yet for ${state.selectedJobId}.`;
        return;
      }
      logNode.textContent = await response.text();
    } catch (error) {
      logNode.textContent = `Unable to load log: ${error.message}`;
    }
  }

  function readCheckedOptions(containerId) {
    return Array.from(byId(containerId).querySelectorAll("input[type='checkbox']:checked"))
      .map((input) => input.dataset.optionId);
  }

  function readEnabledFeatures() {
    return Array.from(byId("feature-grid").querySelectorAll("input[type='checkbox']")).reduce((acc, input) => {
      acc[input.dataset.featureId] = input.checked;
      return acc;
    }, {});
  }

  function collectCoreUser(role) {
    const current = state.config.users[role];
    const password = byId(`user-${role}-password`).value.trim();
    const payload = {
      name: byId(`user-${role}-name`).value.trim(),
      passwordHash: current.passwordHash
    };

    if (password) {
      payload.password = password;
    }

    if (role === "admin") {
      payload.sshKeys = splitListInput(byId("user-admin-ssh-keys").value);
    }

    if (role === "student") {
      payload.autologinOnClients = byId("user-student-autologin").checked;
      payload.resetHome = byId("user-student-reset-home").checked;
    }

    return payload;
  }

  function collectExtraUsers() {
    return Array.from(document.querySelectorAll(".extra-user-card")).map((card) => {
      const name = card.querySelector(".extra-user-name").value.trim();
      const description = card.querySelector(".extra-user-description").value.trim();
      const groups = splitListInput(card.querySelector(".extra-user-groups").value);
      const sshKeys = splitListInput(card.querySelector(".extra-user-ssh-keys").value);
      const password = card.querySelector(".extra-user-password").value.trim();
      const passwordHash = card.dataset.passwordHash || "";

      if (!name && !description && groups.length === 0 && sshKeys.length === 0 && !password) {
        return null;
      }

      const payload = {
        name,
        description: description || name,
        extraGroups: groups,
        sshKeys
      };

      if (password) {
        payload.password = password;
      } else if (passwordHash) {
        payload.passwordHash = passwordHash;
      }

      return payload;
    }).filter(Boolean);
  }

  function buildConfigPayload() {
    const currentFeatures = state.config.features || {};
    const features = readEnabledFeatures();

    return {
      schemaVersion: state.config.schemaVersion || 1,
      network: {
        masterDhcpIp: byId("network-master-dhcp-ip").value.trim(),
        networkBase: byId("network-base").value.trim(),
        masterHostNumber: Number(byId("network-master-host-number").value),
        ifaceName: byId("network-iface-name").value.trim()
      },
      hosts: {
        controller: {
          name: byId("controller-host-name").value.trim()
        },
        clients: {
          count: Number(byId("clients-count").value),
          naming: {
            prefix: byId("clients-prefix").value.trim(),
            padTo: Number(byId("clients-pad-to").value)
          }
        }
      },
      users: {
        admin: collectCoreUser("admin"),
        teacher: collectCoreUser("teacher"),
        student: collectCoreUser("student"),
        extraUsers: collectExtraUsers()
      },
      software: {
        presets: readCheckedOptions("software-presets-grid"),
        hostScopes: {
          controller: readCheckedOptions("software-controller-grid"),
          clients: readCheckedOptions("software-client-grid")
        },
        extraPackages: splitListInput(byId("software-extra-packages").value),
        desktop: {
          studentFavorites: splitListInput(byId("software-student-favorites").value),
          staffFavorites: splitListInput(byId("software-staff-favorites").value)
        },
        vscode: {
          studentPresets: readCheckedOptions("student-vscode-grid"),
          adminPresets: readCheckedOptions("admin-vscode-grid")
        }
      },
      features: {
        ...currentFeatures,
        binaryCache: {
          enable: Boolean(features.binaryCache)
        },
        homeReset: {
          enable: Boolean(features.homeReset)
        },
        screensaver: {
          enable: Boolean(features.screensaver)
        },
        veyon: {
          enable: Boolean(features.veyon)
        },
        guiBackend: {
          enable: Boolean(features.guiBackend),
          port: Number(byId("gui-backend-port").value),
          repoRoot: state.config.features.guiBackend.repoRoot
        }
      },
      org: {
        homepageUrl: byId("org-homepage-url").value.trim(),
        git: {
          student: {
            name: byId("org-student-git-name").value.trim(),
            email: byId("org-student-git-email").value.trim()
          },
          admin: {
            name: byId("org-admin-git-name").value.trim(),
            email: byId("org-admin-git-email").value.trim()
          }
        }
      },
      locale: {
        timeZone: byId("locale-time-zone").value.trim(),
        defaultLocale: byId("locale-default-locale").value.trim(),
        extraLocale: byId("locale-extra-locale").value.trim(),
        keyboardLayout: byId("locale-keyboard-layout").value.trim(),
        consoleKeyMap: byId("locale-console-keymap").value.trim()
      }
    };
  }

  async function saveConfig(event) {
    event.preventDefault();
    try {
      const payload = buildConfigPayload();
      const response = await requestJson("/api/config", {
        method: "POST",
        body: JSON.stringify(payload)
      });
      state.config = response.config;
      showFlash(`Configuration saved to ${response.configPath}.`, "success");
      await refreshStatusAndJobs();
      renderAll();
    } catch (error) {
      showFlash(`Save failed: ${error.message}`, "error");
    }
  }

  async function refreshStatusAndJobs() {
    const [status, jobs] = await Promise.all([
      requestJson("/api/status"),
      requestJson("/api/jobs")
    ]);
    state.status = status;
    state.jobs = jobs;

    if (!state.selectedJobId && jobs.length > 0) {
      state.selectedJobId = jobs[0].id;
    }
  }

  async function refreshConfigFromServer() {
    state.config = await requestJson("/api/config");
  }

  async function queueValidate() {
    try {
      const job = await requestJson("/api/validate", {
        method: "POST",
        body: JSON.stringify({})
      });
      state.selectedJobId = job.id;
      showFlash(`Queued ${job.kind}.`, "success");
      await refreshStatusAndJobs();
      renderJobs();
      await refreshSelectedLog();
    } catch (error) {
      showFlash(`Validate failed to queue: ${error.message}`, "error");
    }
  }

  async function queueBuild(target) {
    try {
      const job = await requestJson("/api/build", {
        method: "POST",
        body: JSON.stringify({ target })
      });
      state.selectedJobId = job.id;
      showFlash(`Queued build target ${target}.`, "success");
      await refreshStatusAndJobs();
      renderJobs();
      await refreshSelectedLog();
    } catch (error) {
      showFlash(`Build failed to queue: ${error.message}`, "error");
    }
  }

  async function queueDeploy(target, host) {
    try {
      const job = await requestJson("/api/deploy", {
        method: "POST",
        body: JSON.stringify(host ? { target, host } : { target })
      });
      state.selectedJobId = job.id;
      showFlash(`Queued deploy target ${target}.`, "success");
      await refreshStatusAndJobs();
      renderJobs();
      await refreshSelectedLog();
    } catch (error) {
      showFlash(`Deploy failed to queue: ${error.message}`, "error");
    }
  }

  async function refreshDashboard() {
    try {
      await Promise.all([
        refreshConfigFromServer(),
        refreshStatusAndJobs()
      ]);
      renderAll();
      await refreshSelectedLog();
      showFlash("Dashboard refreshed.", "info");
    } catch (error) {
      showFlash(`Refresh failed: ${error.message}`, "error");
    }
  }

  function renderAll() {
    renderStatus();
    renderCoreUsers();
    renderExtraUsers();
    renderSoftware();
    renderFeatures();
    renderAdvancedFields();
    renderBuildActions();
    renderDeployHostOptions();
    renderJobs();
  }

  function addExtraUser() {
    const container = byId("extra-users-list");
    if (container.querySelector(".empty-state")) {
      container.innerHTML = "";
    }
    const nextIndex = container.querySelectorAll(".extra-user-card").length;
    container.insertAdjacentHTML("beforeend", extraUserRowMarkup({
      name: "",
      description: "",
      extraGroups: ["networkmanager"],
      sshKeys: [],
      passwordHash: ""
    }, nextIndex));
    bindExtraUserActions();
  }

  function bindEvents() {
    byId("config-form").addEventListener("submit", saveConfig);
    byId("reload-config").addEventListener("click", refreshDashboard);
    byId("refresh-dashboard").addEventListener("click", refreshDashboard);
    byId("refresh-jobs").addEventListener("click", async () => {
      await refreshStatusAndJobs();
      renderJobs();
      await refreshSelectedLog();
    });
    byId("refresh-log").addEventListener("click", refreshSelectedLog);
    byId("add-extra-user").addEventListener("click", addExtraUser);
    byId("run-validate").addEventListener("click", queueValidate);
    byId("deploy-controller").addEventListener("click", () => queueDeploy("controller"));
    byId("deploy-all").addEventListener("click", () => queueDeploy("all"));
    byId("deploy-host").addEventListener("click", () => {
      queueDeploy("host", byId("deploy-host-select").value);
    });
  }

  async function tick() {
    try {
      await refreshStatusAndJobs();
      renderStatus();
      renderJobs();
      if (state.selectedJobId) {
        await refreshSelectedLog();
      }
    } catch (_error) {
      // Silent background refresh failure; explicit actions already show flash errors.
    }
  }

  function startPolling() {
    if (state.refreshTimer) {
      window.clearInterval(state.refreshTimer);
    }
    state.refreshTimer = window.setInterval(tick, 5000);
  }

  renderAll();
  bindEvents();
  startPolling();
  refreshSelectedLog();
}());
