{
  masterDhcpIp = "192.168.1.10";
  networkBase = "10.10.0";
  pcCount = 2;
  masterHostNumber = 99;
  ifaceName = "enp1s0";

  adminUser = "admin";
  teacherUser = "teacher";
  studentUser = "student";

  teacherPassword = "teacher-hash";
  studentPassword = "student-hash";
  adminPassword = "admin-hash";

  extraUsers = [
    {
      name = "teacher";
      passwordHash = "conflict-hash";
    }
  ];

  homepageUrl = "https://example.com";
  studentGitName = "student";
  studentGitEmail = "student@example.com";
  adminGitName = "admin";
  adminGitEmail = "admin@example.com";

  timeZone = "Europe/Rome";
  defaultLocale = "en_US.UTF-8";
  extraLocale = "it_IT.UTF-8";
  keyboardLayout = "it";
  consoleKeyMap = "it2";
}
