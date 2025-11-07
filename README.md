<div align="center">
  <p>
    <a href="https://discord.gg/ZaEwHfDD5N"><img src="https://img.shields.io/discord/1296858234853789826?style=for-the-badge&label=Discord&logo=discord&logoColor=white" /></a>
    <a href="https://playliga.gg/#/#download"><img src="https://img.shields.io/badge/download-latest-salmon?style=for-the-badge&logo=github" /></a>
    <a href="https://github.com/playliga/prototype/milestones"><img src="https://img.shields.io/badge/view_the-roadmap-blue?style=for-the-badge&logo=rocket&logoColor=white" /></a>
  </p>
  <p>AMX Mod X and SourceMod Plugins for LIGA Esports Manager.</p>
  <p>Additional game configuration files and maps are also provided by this repository.</p>
</div>

# APIs and Technologies

- Node `v22.x`
- GoldSrc Engine
  - [AMX Mod X](https://www.amxmodx.org/) `v1.9.0` build `5294`
  - [Metamod](http://metamod.org/) `v1.21.1-am`
  - [ReGameDLL](https://github.com/rehlds/ReGameDLL_CS) `5.26.0.668`
- Source Engine
  - [SourceMod](https://www.sourcemod.net/) `v1.12.0`
  - [Metamod Source](https://www.sourcemm.net/) `v1.12.0`

# Getting Started

```bash
npm install
npx tsx cli/compiler.mts
```

# VSCode Extension

Install the recommended workspace extension and configure the SourceMod extension paths.

```json
"SourcePawnLanguageServer.compiler.path": "<path_to_project>/generated/csgo/addons/sourcemod/scripting/spcomp.exe",
"SourcePawnLanguageServer.includeDirectories": ["<path_to_project>/generated/csgo/addons/sourcemod/scripting/include"],
"sourcepawn.outputDirectoryPath": "<path_to_project>/config/csgo/addons/sourcemod/plugins/",
```
