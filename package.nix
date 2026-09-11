{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;

  platformMap = {
    "x86_64-darwin" = "darwin_amd64";
    "aarch64-darwin" = "darwin_arm64";
    "x86_64-linux" = "linux_amd64";
    "aarch64-linux" = "linux_arm64";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "perles is not available for ${stdenv.hostPlatform.system}. Supported: ${lib.concatStringsSep ", " (lib.attrNames platformMap)}");

  tarball = fetchurl {
    url = "https://github.com/zjrosen/perles/releases/download/v${version}/perles_${version}_${platform}.tar.gz";
    hash = sources.platforms.${platform};
  };
in
stdenv.mkDerivation {
  pname = "perles";
  inherit version;

  src = tarball;
  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  # Upstream builds with CGO_ENABLED=0, so the binaries are static and need no
  # patching; the darwin ones are ad-hoc signed and must not be stripped.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 perles $out/bin/perles
    runHook postInstall
  '';

  # Completions come from cobra in the binary itself, so only when the build
  # machine can run the host binary.
  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd perles \
      --bash <($out/bin/perles completion bash) \
      --zsh <($out/bin/perles completion zsh) \
      --fish <($out/bin/perles completion fish)
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/perles --version | grep -qF "${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Terminal UI for beads issue tracking with BQL search";
    homepage = "https://github.com/zjrosen/perles";
    changelog = "https://github.com/zjrosen/perles/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames platformMap;
    mainProgram = "perles";
  };
}
