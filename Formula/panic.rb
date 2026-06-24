class Panic < Formula
  desc "One-step hide-and-lock kill-switch for macOS"
  homepage "https://github.com/Di-kairos/panic"
  url "https://github.com/Di-kairos/panic/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "e8ea6ace3768543a5e88be02162f4ed7ac2f48d3c555d392e106d8b0b5c3a1ed"
  license "MIT"

  def install
    bin.install "panic"
  end

  test do
    assert_match "panic", shell_output("#{bin}/panic version")
  end
end
