{ lib, pkgs, ... }:
let
  listenAddress = "127.0.0.1";
  port = 7997;
  apiKey = "openclaw-local-infinity";
  modelId = "Alibaba-NLP/gte-modernbert-base";
  modelRevision = "e7f32e3c00f91d699e8c43b53106206bcc72bb22";
  servedModelName = "${modelId}@${modelRevision}";
  stateRoot = "/var/lib/openclaw-embeddings/text-memory";
  cacheRoot = "/var/cache/openclaw-embeddings/text-memory";
  launcher = "/home/iva/.openclaw/embeddings/openclaw-infinity-emb/bin/openclaw-infinity-emb";

  configFile = pkgs.writeText "openclaw-embeddings-text-memory.json" (
    builtins.toJSON {
      inherit apiKey cacheRoot listenAddress port;
      telemetry = false;
      environment = {
        CUDA_VISIBLE_DEVICES = "0";
        INFINITY_BETTERTRANSFORMER = "false";
      };
      extraArgs = [
        "--log-level"
        "info"
      ];
      models = [
        {
          repoId = modelId;
          revision = modelRevision;
          inherit servedModelName;
          engine = "torch";
          device = "cuda";
          batchSize = 16;
          dtype = "auto";
          embeddingDtype = "float32";
          modelWarmup = true;
          trustRemoteCode = false;
          allowPatterns = [
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
        }
      ];
    }
  );
in
{
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
      ConditionPathExists = launcher;
    };
  };
}
