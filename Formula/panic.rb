class Panic < Formula
  desc "One-step hide-and-lock kill-switch for macOS"
  homepage "https://github.com/Di-kairos/panic"
  url "https://github.com/Di-kairos/panic/archive/refs/tags/v0.1.14.tar.gz"
  sha256 "6747d08bcbdac783935a44b5696b1e8c8262582295959d5c74a052b2442831ee"
  license "MIT"

  def install
    bin.install "panic"
  end

  test do
    assert_match "panic", shell_output("#{bin}/panic version")
  end
end
