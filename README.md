# GodotDrone

Important: this project uses Git LFS for `png` and `jpg` assets.

Do not use GitHub `Download ZIP` for a working copy.

Recommended editor/runtime version: Godot `4.6`.

Setup:

```bash
git lfs install
git clone <repo-url>
cd GodotDrone
git lfs pull
```

If Godot still reports missing textures after cloning, close the editor, delete the local `.godot/` folder, and open the project again so imports are rebuilt.

Known runtime/export behavior:

- The assembled drone is saved to `user://exported_drone.tscn`.
- Exported builds should load the `user://` drone first.
- `build/` and temporary model files should not be committed.
