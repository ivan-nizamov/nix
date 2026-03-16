{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  installShellFiles,
}:
buildGo126Module (finalAttrs: {
  pname = "neru";
  version = "1.27.1-1-g028c59a";

  src = fetchFromGitHub {
    owner = "y3owk1n";
    repo = "neru";
    rev = "028c59adb6444290d4fde75acc6a2b7bdc02baf8";
    hash = "sha256-9JguIrOh8JhUgf0Nis8i34Ax+vU8c1dbu/B6hGflVeE=";
  };

  patches = [
    ./patches/linux-systray-blocking.patch
  ];

  vendorHash = "sha256-KLooAJ1TmUNf0lUQNgwpin32bpTtwzXI/orRH3htOKA=";

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [ "cmd/neru" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/y3owk1n/neru/internal/cli.Version=${finalAttrs.version}"
    "-X github.com/y3owk1n/neru/internal/cli.GitCommit=028c59adb6444290d4fde75acc6a2b7bdc02baf8"
  ];

  postInstall = ''
    installShellCompletion --cmd neru \
      --bash <($out/bin/neru completion bash) \
      --fish <($out/bin/neru completion fish) \
      --zsh <($out/bin/neru completion zsh)
  '';

  meta = {
    description = "Keyboard-driven navigation daemon built from Neru's current Linux stub implementation";
    homepage = "https://github.com/y3owk1n/neru";
    license = lib.licenses.mit;
    mainProgram = "neru";
    platforms = lib.platforms.linux;
  };
})
