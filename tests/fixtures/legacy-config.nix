{
  masterDhcpIp = "192.168.1.10";
  networkBase = "10.10.0";
  pcCount = 3;
  masterHostNumber = 99;
  ifaceName = "enp1s0";

  adminUser = "labadmin";
  teacherUser = "teacher";
  studentUser = "student";

  teacherPassword = "teacher-hash";
  studentPassword = "student-hash";
  adminPassword = "admin-hash";

  extraUsers = [
    {
      name = "alice";
      passwordHash = "alice-hash";
    }
  ];

  homepageUrl = "https://example.com";
  studentGitName = "student";
  studentGitEmail = "student@example.com";
  adminGitName = "labadmin";
  adminGitEmail = "labadmin@example.com";

  timeZone = "Europe/Rome";
  defaultLocale = "en_US.UTF-8";
  extraLocale = "it_IT.UTF-8";
  keyboardLayout = "it";
  consoleKeyMap = "it2";
}
