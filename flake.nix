{
  description = "Devshell for the luarocks-exploit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      luajit = pkgs.luajit_openresty.withPackages (ps: [
        ps.argparse
        ps.lua-curl
        ps.lua-cjson
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          luajit
          pkgs.curl
        ];
      };
    };
}
