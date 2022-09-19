{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    nixMaster.url = "github:nixos/nix";
  };
  outputs = { self, nixpkgs, ... }@inputs: {
    packages.x86_64-linux =
    let
      fs-options = [ "ext3" "ext4" "nilfs2" "btrfs" "xfs" "f2fs" ];
      machine = {
        virtualisation.emptyDiskImages = [ 1024 ];
        environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [ go hello xfsprogs btrfs-progs f2fs-tools nilfs-utils ];
        nix.settings = {
          require-sigs = false;
          experimental-features = [ "nix-command" ];
          sync-before-registering = false;
        };
      };
      nixMaster = nixpkgs.legacyPackages.x86_64-linux.nix.overrideAttrs ( old: {
        src = inputs.nixMaster;
      });
      #nixPatched = nixpkgs.legacyPackages.x86_64-linux.nix.overrideAttrs ( old: {
        #src = inputs.nixPatched;
      #});
      make-corrupt-schema-test = { nix, fs }: with nixpkgs.legacyPackages.x86_64-linux; nixosTest ({ pkgs, ... }: {
        name = "corrupt-schema-test-${fs}";
        nodes.machine = lib.recursiveUpdate machine {
          nix.package = nix;
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          machine.succeed("mkfs.${fs} /dev/vdb")
          machine.succeed("mkdir /mnt")
          machine.succeed("mount /dev/vdb /mnt")
          machine.succeed("sync")
          machine.execute("nix copy ${hello} --to /mnt --offline", timeout=1)
          machine.crash()

          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("mkdir -p /mnt")
          machine.succeed("mount /dev/vdb /mnt")
          machine.succeed("nix store verify --all --store /mnt --no-trust")
        '';
      });
      make-corrupt-contents-test = { nix, fs }: with nixpkgs.legacyPackages.x86_64-linux; nixosTest ({ pkgs, ... }: {
        name = "corrupt-contents-test-${fs}";
        nodes.machine = lib.recursiveUpdate machine {
          nix.package = nix;
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          machine.succeed("mkfs.${fs} /dev/vdb")
          machine.succeed("mkdir /mnt")
          machine.succeed("mount /dev/vdb /mnt")
          machine.succeed("nix copy ${hello} --to /mnt --offline")
          machine.succeed("sync")
          machine.execute("nix copy ${go} --to /mnt --offline", timeout=5)
          machine.crash()

          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("mkdir -p /mnt")
          machine.succeed("mount /dev/vdb /mnt")
          machine.succeed("nix store verify --all --store /mnt --no-trust")
        '';
      });

      make-all-fs-tests = make-test: nix: builtins.listToAttrs (builtins.map (fs: { name = fs; value = make-test { inherit nix fs; }; }) fs-options);
      combine-tests = name: tests: with nixpkgs.legacyPackages.x86_64-linux; linkFarm name (lib.attrsets.mapAttrsToList (name: value: { inherit (value) name; path = value; }) tests);
      in with nixpkgs.legacyPackages.x86_64-linux; rec {

        inherit nixMaster;

        corrupt-schema-tests = make-all-fs-tests make-corrupt-schema-test nix;
        corrupt-contents-tests = make-all-fs-tests make-corrupt-contents-test nix;

        corrupt-schema-test-list = combine-tests "corrupt-schema-tests" corrupt-schema-tests;
        corrupt-contents-test-list = combine-tests "corrupt-contents-tests" corrupt-contents-tests;

        all-test-list = linkFarm "all-tests" [
          { name = "corrupt-schema-tests"; path = corrupt-schema-test-list; }
          { name = "corrupt-contents-tests"; path = corrupt-contents-test-list; }
        ];
        default = all-test-list;
      };
  };
}
