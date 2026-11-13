cask "caffeine" do
  version "1.0.0"
  sha256 "93713ac9b20fb43880e48d9eb3134c610e94ce4a1776c3a2d57b9887f9b509c1"

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
end
