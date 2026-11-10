// Plasma desktop script: builds the panel, unless one with the Desktops widget
// already exists (so re-running the installer never undoes later changes).
// Run by install.sh through org.kde.PlasmaShell.evaluateScript.

var built = panels().some(function (p) {
  return p.widgets().some(function (w) { return w.type === "org.fak3.desktops"; });
});

if (built) {
  print("panel: already set up, leaving it alone");
} else {
  panels().forEach(function (p) { p.remove(); });

  var panel = new Panel;
  panel.location = "bottom";
  panel.height = 38;
  panel.floating = true;
  panel.opacity = "translucent";

  // Clock: JetBrains Mono, seconds always, 24-hour, "Tue 10 Nov" beside the time.
  var clock = panel.addWidget("org.kde.plasma.digitalclock");
  clock.currentConfigGroup = ["Appearance"];
  clock.writeConfig("autoFontAndSize", false);
  clock.writeConfig("fontFamily", "JetBrainsMono Nerd Font");
  clock.writeConfig("fontSize", 12);
  clock.writeConfig("fontStyleName", "Regular");
  clock.writeConfig("fontWeight", 400);
  clock.writeConfig("showSeconds", "Always");
  clock.writeConfig("use24hFormat", 2);
  clock.writeConfig("dateFormat", "custom");
  clock.writeConfig("customDateFormat", "ddd d MMM");
  clock.writeConfig("dateDisplayFormat", "BesideTime");

  var launcher = panel.addWidget("org.kde.plasma.kickoff");
  launcher.currentConfigGroup = ["General"];
  launcher.writeConfig("icon", "draw-circle-symbolic");
  launcher.writeConfig("favoritesDisplay", 1);
  launcher.writeConfig("systemFavorites", "suspend,hibernate,reboot,shutdown");

  // Pinned apps, in this order. Apps that are not installed are left out, since
  // the task manager would show them as blank icons.
  var pinned = [
    "systemsettings.desktop",
    "org.kde.kcalc.desktop",
    "org.kde.kwrite.desktop",
    "app.zen_browser.zen.desktop",
    "brave-browser.desktop",
    "org.mozilla.firefox.desktop",
    "com.mitchellh.ghostty.desktop",
    "t3code.desktop",
    "com.microsoft.VSCode.desktop",
    "slack.desktop",
    "org.telegram.desktop.desktop",
    "com.discordapp.Discord.desktop",
    "com.obsproject.Studio.desktop",
    "chatgpt.desktop"
  ];
  var launchers = [];
  pinned.forEach(function (app) {
    if (applicationExists(app)) launchers.push("applications:" + app);
  });
  launchers.splice(1, 0, "preferred://filemanager");
  var tasks = panel.addWidget("org.kde.plasma.icontasks");
  tasks.currentConfigGroup = ["General"];
  tasks.writeConfig("launchers", launchers);
  tasks.writeConfig("iconSpacing", 0);
  tasks.writeConfig("middleClickAction", "None");
  tasks.writeConfig("showOnlyCurrentDesktop", false);
  tasks.writeConfig("wheelEnabled", "AllTask");

  panel.addWidget("org.fak3.desktops");
  panel.addWidget("org.kde.plasma.marginsseparator");
  panel.addWidget("org.fak3.ramindicator");

  panel.addWidget("org.kde.plasma.systemtray");
  panel.addWidget("org.kde.plasma.showdesktop");

  print("panel: built");
}
