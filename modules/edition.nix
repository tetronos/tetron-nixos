# The tetron-nixos edition: every suite component on, as the Debian
# TetronOS image installs them.
{ ... }:
{
  services.tetron.enable = true;
  programs.tetron-tui.enable = true;
  services.tetron-console.enable = true;
}
