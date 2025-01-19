{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # nodejs = pkgs.nodejs_22;
        python = (
          pkgs.python3.withPackages (
            ps: with ps; [
              torch
              torchsde
              torchvision
              torchaudio
              numpy
              einops
              transformers
              tokenizers
              (sentencepiece.overrideAttrs (oldAttrs: {
                buildInputs = [
                  (pkgs.sentencepiece.overrideAttrs (oldAttrs: {
                    postPatch = ''
                      substituteInPlace CMakeLists.txt \
                        --replace '\$'{exec_prefix}/'$'{CMAKE_INSTALL_LIBDIR} '$'{CMAKE_INSTALL_FULL_LIBDIR} \
                        --replace '\$'{prefix}/'$'{CMAKE_INSTALL_INCLUDEDIR} '$'{CMAKE_INSTALL_FULL_INCLUDEDIR} \
                        --replace "option(SPM_ENABLE_TCMALLOC \"Enable TCMalloc if available.\" ON)" \
                                  "option(SPM_ENABLE_TCMALLOC \"Enable TCMalloc if available.\" OFF)" \
                        --replace "option(SPM_TCMALLOC_STATIC \"Link static library of TCMALLOC.\" OFF)" \
                                  "option(SPM_TCMALLOC_STATIC \"Link static library of TCMALLOC.\" OFF)"
                    '';
                  })).dev
                ];
              }))
              safetensors
              aiohttp
              pyyaml
              pillow
              scipy
              tqdm
              psutil
            ]
          )
        );

        checkpoint = pkgs.stdenv.mkDerivation {
          pname = "v1-5-pruned-emaonly-checkpoint";
          version = "1.0";

          src = pkgs.fetchurl {
            url = "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors";
            sha256 = "sha256-bOAWFomzhTrKoDd57JPq/nWgL0ztZZvuA/UHl4Bvovo=";
          };

          dontUnpack = true;

          installPhase = ''
            mkdir -p $out
            cp $src $out/v1-5-pruned-emaonly.ckpt
          '';
        };

      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "ComfyUI";
          version = "0.3.12";
          pyproject = true;

          src = pkgs.fetchFromGitHub {
            owner = "comfyanonymous";
            repo = "ComfyUI";
            rev = "b4de04a1c1e90c4183d7880e49ce7e80d82c7c0a";
            sha256 = "sha256-LlTo1XKVaDczgjKuaasYGltGR4AC/7vEn5A6DsY5U68=";
          };

          buildInputs = [
            python
            python.pkgs.pip
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp -r --no-preserve=mode,ownership $src/* $out
            chmod -R u+w $out

            ln -s ${checkpoint}/v1-5-pruned-emaonly.ckpt \
              $out/models/checkpoints/v1-5-pruned-emaonly.safetensors

            echo '#!/bin/sh' > $out/bin/ComfyUI
            echo "export MALLOC=system" >> $out/bin/ComfyUI
            echo "mkdir -p \$HOME/comfyui/user" >> $out/bin/ComfyUI
            echo "mkdir -p \$HOME/comfyui/temp" >> $out/bin/ComfyUI
            echo "mkdir -p \$HOME/comfyui/input" >> $out/bin/ComfyUI
            echo "mkdir -p \$HOME/comfyui/output" >> $out/bin/ComfyUI
            echo "exec ${python}/bin/python $out/main.py \\" >> $out/bin/ComfyUI
            echo "--user-directory=\$HOME/comfyui/user \\" >> $out/bin/ComfyUI
            echo "--temp-directory=\$HOME/comfyui/temp \\" >> $out/bin/ComfyUI
            echo "--input-directory=\$HOME/comfyui/input \"\$@\" \\" >> $out/bin/ComfyUI
            echo "--output-directory=\$HOME/comfyui/output" >> $out/bin/ComfyUI
            chmod +x $out/bin/ComfyUI
          '';
        };
      }
    );
}
