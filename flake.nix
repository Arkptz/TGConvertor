{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:arkptz/nixpkgs/nixos-unstable";
    nixpkgs_redis = {
      url = "github:nixos/nixpkgs?rev=e1ee359d16a1886f0771cc433a00827da98d861c";
    }; # memory leak on unstable

    poetry2nix = {
      url = "github:arkptz/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    poetry2nix,
    nixpkgs,
    nixpkgs_redis,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      # pkgs = nixpkgs.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;
        # Переопределение пакетов из nixpkgs_redis, если это необходимо
        overlays = [
          (self: super: {
            redis = (import nixpkgs_redis {inherit system;}).redis;
            # curio = (import nixpkgs-stable {inherit system;}).curio;
          })
          poetry2nix.overlays.default
        ];
      };

      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication mkPoetryEnv overrides cleanPythonSources;

      cleanSources = cleanPythonSources {src = ./.;};
      defaultPython = pkgs.python3;
      # pythonPackages = pkgs.python311Packages;
      pythonPackages = defaultPython.pkgs;
      defaultOverrides =
        overrides.withDefaults
        (
          self: super: {
            # fastapi = super.fastapi.overridePythonAttrs (old: {
            #   version = "0.111.0";
            # });
            # pydantic-settings = super.pydantic-settings.overridePythonAttrs (old: {
            #   version = "2.2.1";
            # });
            # pyqt5 = super.pyqt5.overridePythonAttrs (old: {
            #   version = "5.15.10";
            # });
            # sqlalchemy = super.sqlalchemy.overridePythonAttrs (old: {
            #   version = "2.0.30";
            # });
            # sqlmodel = super.sqlmodel.overridePythonAttrs (old: {
            #   version = "0.0.18";
            # });
            async_timeout = pythonPackages.async_timeout.overridePythonAttrs (old: {
              preFixup = ''
                find $out -name 'RECORD' -delete
                find  $out -type d -name '__pycache__' -exec rm -r {} +
                find  $out -name '*.pyc' -delete
                find  $out -name '*.*.pyc' -delete
              '';
            });
            click = pythonPackages.click;
            celery = pythonPackages.celery;
            faker = pythonPackages.faker;
            yarl = pythonPackages.yarl;
            aiohttp = pythonPackages.aiohttp;
            python-socks = pythonPackages.python-socks;
            asyncpg = pythonPackages.asyncpg;
            celery-types = pythonPackages.celery-types;
          }
        );

      defaultAttrs = {
        projectDir = cleanSources;
        python = defaultPython;
        overrides = defaultOverrides;
      };
    in {
      devShells.default = let
        poetryEnv = mkPoetryEnv defaultAttrs;
      in
        pkgs.mkShell {
          # inputsFrom = [self.packages.${system}.myapp];
          nativeBuildInputs = with pkgs; [
            poetry
            nixpkgs-fmt
            pre-commit
            # poetry2nix
          ];
          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
          ];
          packages = with pkgs; [
            poetryEnv
            poetry
          ];
          # packages = with pkgs; [
          #   poetryEnv
          #   poetry
          #   # pkg-config
          #   # clang
          #   # gnumake
          #   # cmake
          #   # gcc
          #   # stdenv.cc.cc.lib
          #   # polylith
          # ];
          NIX_LD = "${pkgs.stdenv.cc}/lib64";
          shellHook = ''
            unset SOURCE_DATE_EPOCH
            export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
            export PYTHONPATH=$PYTHONPATH:${poetryEnv}/lib/python:${poetryEnv}/lib/python3.11/site-packages
            ln -sfT ${poetryEnv.out} ./.venv
          '';
        };
    });
}
