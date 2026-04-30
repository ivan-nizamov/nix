{ config, lib, pkgs, ... }:
let
  cfg = config.local.openclaw.embeddings;
  listenAddress = "127.0.0.1";
  port = 7997;
  apiKey = "openclaw-local-infinity";
  modelId = cfg.modelId;
  modelRevision = cfg.modelRevision;
  servedModelName = "${modelId}@${modelRevision}";
  stateRoot = "/var/lib/openclaw-embeddings/text-memory";
  cacheRoot = "/var/cache/openclaw-embeddings/text-memory";
  launcher = "/nix/store/1d1qx2fr8ni1zkljrhlgfnkx14n6kgjv-openclaw-infinity-emb/bin/openclaw-infinity-emb";

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
  options.local.openclaw.embeddings = {
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

  config = {
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
        ExecStart = launcher;
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
