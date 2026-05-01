{ config, lib, pkgs, ... }:
let
  cfg = config.local.openclaw.embeddings;
  openclawEnabled = config.local.openclaw.enable;
  listenAddress = "127.0.0.1";
  port = 7997;
  apiKey = "openclaw-local-infinity";
  modelId = cfg.modelId;
  modelRevision = cfg.modelRevision;
  servedModelName = "${modelId}@${modelRevision}";
  stateRoot = "/var/lib/openclaw-embeddings/text-memory";
  cacheRoot = "/var/cache/openclaw-embeddings/text-memory";
  python = pkgs.python312;
  pythonPkgs = pkgs.python312Packages;
  infinityEmb = pythonPkgs.buildPythonPackage rec {
    pname = "infinity-emb";
    version = "0.0.77";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/i/infinity_emb/infinity_emb-${version}-py3-none-any.whl";
      hash = "sha256-Xbq0nRPyEhecDCtaqNEjDGEPBRp49W7H6aw3uDk47GU=";
    };

    propagatedBuildInputs = with pythonPkgs; [
      huggingface-hub
      numpy
    ];

    pythonImportsCheck = [ "infinity_emb" ];
  };
  pythonEnv = python.withPackages (ps: with ps; [
    anyio
    annotated-types
    backoff
    certifi
    charset-normalizer
    click
    diskcache
    distro
    fastapi
    filelock
    fsspec
    future
    h11
    httptools
    huggingface-hub
    idna
    jinja2
    joblib
    lz4
    markdown-it-py
    markupsafe
    mdurl
    monotonic
    mpmath
    networkx
    numpy
    orjson
    packaging
    pillow
    posthog
    prometheus-client
    prometheus-fastapi-instrumentator
    psutil
    pydantic
    pydantic-core
    pygments
    python-dateutil
    pyyaml
    regex
    requests
    rich
    safetensors
    scikit-learn
    scipy
    sentence-transformers
    setuptools
    shellingham
    six
    sniffio
    starlette
    sympy
    threadpoolctl
    tokenizers
    torchWithoutCuda
    tqdm
    transformers
    typer
    typing-extensions
    typing-inspection
    urllib3
    uvicorn
  ]);
  launcherPy = pkgs.writeText "openclaw-embeddings-launcher.py" ''
    import json
    import os
    import pathlib
    import sys


    def _die(message: str) -> "None":
        print(f"openclaw-infinity-emb: {message}", file=sys.stderr)
        raise SystemExit(1)


    def _mkdir(path: pathlib.Path) -> pathlib.Path:
        path.mkdir(parents=True, exist_ok=True)
        return path


    def _join_multi(values):
        return ";".join(str(value) for value in values)


    def _env_bool(value: bool) -> str:
        return "1" if value else "0"


    def _read_text(path: str) -> str:
        return pathlib.Path(path).read_text(encoding="utf-8").strip()


    def _load_config():
        config_path = os.environ.get("OPENCLAW_EMBEDDINGS_CONFIG_PATH")
        if not config_path:
            _die("OPENCLAW_EMBEDDINGS_CONFIG_PATH is not set")

        with open(config_path, encoding="utf-8") as handle:
            return json.load(handle)


    def _configure_runtime_env(config):
        cache_root = _mkdir(pathlib.Path(config["cacheRoot"]))
        hf_home = _mkdir(cache_root / "huggingface")
        hf_hub_cache = _mkdir(hf_home / "hub")
        xdg_cache_home = _mkdir(cache_root / "xdg")
        sentence_transformers_home = _mkdir(cache_root / "sentence-transformers")
        torch_home = _mkdir(cache_root / "torch")
        tmp_dir = _mkdir(cache_root / "tmp")

        env = os.environ.copy()
        env["HF_HOME"] = str(hf_home)
        env["HF_HUB_CACHE"] = str(hf_hub_cache)
        env["TRANSFORMERS_CACHE"] = str(hf_hub_cache)
        env["SENTENCE_TRANSFORMERS_HOME"] = str(sentence_transformers_home)
        env["TORCH_HOME"] = str(torch_home)
        env["XDG_CACHE_HOME"] = str(xdg_cache_home)
        env["TMPDIR"] = str(tmp_dir)
        env["INFINITY_ANONYMOUS_USAGE_STATS"] = _env_bool(config.get("telemetry", False))

        existing_ld_library_path = env.get("LD_LIBRARY_PATH", "")
        ld_library_parts = ["/run/opengl-driver/lib"]
        if existing_ld_library_path:
            ld_library_parts.extend(part for part in existing_ld_library_path.split(":") if part)
        env["LD_LIBRARY_PATH"] = ":".join(dict.fromkeys(ld_library_parts))

        for key, value in config.get("environment", {}).items():
            env[key] = value

        return env, hf_hub_cache


    def _apply_config_overrides(model, resolved_path: str) -> None:
        overrides = model.get("configOverrides") or {}
        if not overrides:
            return

        config_path = pathlib.Path(resolved_path) / "config.json"
        if not config_path.exists():
            _die(f"configOverrides requested but {config_path} does not exist")

        data = json.loads(config_path.read_text(encoding="utf-8"))
        changed = False
        for key, value in overrides.items():
            if data.get(key) != value:
                data[key] = value
                changed = True

        if changed:
            config_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


    def _resolve_model_path(model, hf_hub_cache: pathlib.Path) -> str:
        local_path = model.get("localPath")
        if local_path:
            resolved_path = local_path
        else:
            repo_id = model.get("repoId")
            if not repo_id:
                _die("model entry must set either localPath or repoId")

            from huggingface_hub import snapshot_download

            kwargs = {
                "repo_id": repo_id,
                "cache_dir": str(hf_hub_cache),
            }
            if model.get("revision"):
                kwargs["revision"] = model["revision"]
            if model.get("allowPatterns"):
                kwargs["allow_patterns"] = model["allowPatterns"]

            resolved_path = snapshot_download(**kwargs)

        _apply_config_overrides(model, resolved_path)
        return resolved_path


    def _configure_infinity_env(env, config, resolved_models):
        env["INFINITY_HOST"] = str(config["listenAddress"])
        env["INFINITY_PORT"] = str(config["port"])

        api_key_file = config.get("apiKeyFile")
        api_key = _read_text(api_key_file) if api_key_file else config.get("apiKey", "")
        if api_key:
            env["INFINITY_API_KEY"] = api_key

        env["INFINITY_MODEL_ID"] = _join_multi(model["resolvedPath"] for model in resolved_models)
        env["INFINITY_SERVED_MODEL_NAME"] = _join_multi(
            model["servedModelName"] for model in resolved_models
        )
        env["INFINITY_ENGINE"] = _join_multi(model["engine"] for model in resolved_models)
        env["INFINITY_DEVICE"] = _join_multi(model["device"] for model in resolved_models)
        env["INFINITY_BATCH_SIZE"] = _join_multi(model["batchSize"] for model in resolved_models)
        env["INFINITY_DTYPE"] = _join_multi(model["dtype"] for model in resolved_models)
        env["INFINITY_EMBEDDING_DTYPE"] = _join_multi(
            model["embeddingDtype"] for model in resolved_models
        )
        env["INFINITY_MODEL_WARMUP"] = _join_multi(
            _env_bool(model["modelWarmup"]) for model in resolved_models
        )
        env["INFINITY_TRUST_REMOTE_CODE"] = _join_multi(
            _env_bool(model["trustRemoteCode"]) for model in resolved_models
        )


    def main():
        config = _load_config()
        env, hf_hub_cache = _configure_runtime_env(config)

        resolved_models = []
        for model in config["models"]:
            resolved = dict(model)
            resolved["resolvedPath"] = _resolve_model_path(model, hf_hub_cache)
            resolved_models.append(resolved)

        _configure_infinity_env(env, config, resolved_models)

        command = [
            sys.executable,
            "-m",
            "infinity_emb.cli",
            "v2",
            *config.get("extraArgs", []),
            *sys.argv[1:],
        ]
        model_summary = ", ".join(model["servedModelName"] for model in resolved_models)
        print(
            f"openclaw-infinity-emb: starting {model_summary} on "
            f"{config['listenAddress']}:{config['port']}",
            file=sys.stderr,
        )
        os.execvpe(command[0], command, env)


    if __name__ == "__main__":
        main()
  '';
  launcher = pkgs.writeShellScriptBin "openclaw-infinity-emb" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pythonEnv ]}:$PATH"

    if [ -n "''${PYTHONPATH-}" ]; then
      export PYTHONPATH="${infinityEmb}/${python.sitePackages}:''${PYTHONPATH}"
    else
      export PYTHONPATH="${infinityEmb}/${python.sitePackages}"
    fi

    exec "${pythonEnv}/bin/python" "${launcherPy}" "$@"
  '';

  configFile = pkgs.writeText "openclaw-embeddings-text-memory.json" (
    builtins.toJSON {
      inherit apiKey cacheRoot listenAddress port;
      telemetry = false;
      environment = cfg.environment;
      extraArgs = cfg.extraArgs;
      models = [
        {
          repoId = modelId;
          revision = modelRevision;
          inherit servedModelName;
          engine = "torch";
          device = cfg.device;
          batchSize = cfg.batchSize;
          dtype = cfg.dtype;
          embeddingDtype = cfg.embeddingDtype;
          modelWarmup = cfg.modelWarmup;
          trustRemoteCode = false;
          allowPatterns = cfg.allowPatterns;
        }
      ];
    }
  );
in
{
  options.local.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the local OpenClaw gateway/embeddings stack on this host.";
    };

    embeddings = {
    modelId = lib.mkOption {
      type = lib.types.str;
      default = "Alibaba-NLP/gte-modernbert-base";
      description = "Embedding model repository id.";
    };

    modelRevision = lib.mkOption {
      type = lib.types.str;
      default = "e7f32e3c00f91d699e8c43b53106206bcc72bb22";
      description = "Pinned embedding model revision.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "cuda";
      description = "Infinity embedding device.";
    };

    batchSize = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Infinity embedding batch size.";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Model dtype passed to Infinity.";
    };

    embeddingDtype = lib.mkOption {
      type = lib.types.str;
      default = "float32";
      description = "Embedding dtype passed to Infinity.";
    };

    modelWarmup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to warm the model on startup.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        CUDA_VISIBLE_DEVICES = "0";
        INFINITY_BETTERTRANSFORMER = "false";
      };
      description = "Environment passed to the embeddings launcher config.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--log-level"
        "info"
      ];
      description = "Extra arguments passed to the embeddings launcher.";
    };

    allowPatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "*.json"
        "*.safetensors"
        "*.model"
        "*.txt"
        "tokenizer*"
        "vocab*"
        "special_tokens_map.json"
        "modules.json"
        "sentence_*.json"
      ];
      description = "Allowed Hugging Face model files for the embeddings download.";
    };
    };
  };

  config = lib.mkIf openclawEnabled {
    users.groups.openclaw-embeddings = { };

    users.users.openclaw-embeddings = {
      isSystemUser = true;
      description = "OpenClaw local embeddings service user";
      group = "openclaw-embeddings";
      extraGroups = [
        "render"
        "video"
      ];
      home = "/var/lib/openclaw-embeddings";
      createHome = true;
    };

    systemd.services.openclaw-embeddings = {
      description = "OpenClaw local text embeddings";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        OPENCLAW_EMBEDDINGS_CONFIG_PATH = configFile;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe launcher;
        Restart = "always";
        RestartSec = 2;
        User = "openclaw-embeddings";
        Group = "openclaw-embeddings";
        WorkingDirectory = stateRoot;
        StateDirectory = "openclaw-embeddings/text-memory";
        CacheDirectory = "openclaw-embeddings/text-memory";
        LogsDirectory = "openclaw-embeddings";
        RuntimeDirectory = "openclaw-embeddings";
        RuntimeDirectoryPreserve = "yes";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          stateRoot
          cacheRoot
        ];
      };
    };
  };
}
