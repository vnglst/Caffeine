cask "caffeine" do
  version "1.1.0"
  sha256 "c5bc275765ae1c22021a8db304d482cca9e77677b993ab239ed3bb9eccd98536"

  url "https://github.com/vnglst/Caffeine/releases/download/v#{version}/Caffeine-#{version}.zip"
  name "Caffeine"
  desc "Menu bar app that prevents your Mac from sleeping"
  homepage "https://github.com/vnglst/Caffeine"

  depends_on arch: :arm64
  depends_on macos: :monterey

  app "Caffeine.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Caffeine.app"],
        base:           :appdir,
        writable_paths: ["Caffeine.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.yourname.caffeine"

  # Hyper mode's passwordless rule; zap only, so upgrades keep it.
  zap delete: "/etc/sudoers.d/caffeine"
end
