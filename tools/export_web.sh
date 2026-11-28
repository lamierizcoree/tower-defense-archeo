#!/bin/sh
# Exporte la version web dans build/web (Godot 4.7 et ses modèles d'export installés).
# Usage : GODOT=/chemin/vers/godot sh tools/export_web.sh
set -e
GODOT="${GODOT:-godot}"
mkdir -p build/web
touch build/.gdignore   # Godot ne doit pas importer le build lui-même
"$GODOT" --headless --export-release "Web" build/web/index.html
echo "Export terminé : build/web (à publier sur la branche gh-pages)"
