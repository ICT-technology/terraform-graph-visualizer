#!/usr/bin/env bash
# scripts/check-module-versions.sh
#
# Copyright (c) 2025 ICT.technology KLG (https://ict.technology)
# Author: Ralf Ramge (ralf.ramge@ict.technology)
# License: unrestricted non-commercial use (Business Source License 1.0)

set -euo pipefail

# Colors (disable with NO_COLOR=1)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
if [[ "${NO_COLOR:-}" == "1" ]]; then RED=""; GREEN=""; YELLOW=""; BLUE=""; PURPLE=""; CYAN=""; NC=""; fi

TARGETS_ONLY_REGEX=""; FAN_IN_THRESHOLD=0; SHOW_HELP=0

print_help() {
  cat <<'EOF'
Usage:
  terraform graph | terraform-graph-visualizer.sh [--targets-only <regex>] [--fan-in <N>]
  terraform-graph-visualizer.sh <dot-file> [--targets-only <regex>] [--fan-in <N>]

Options:
  --targets-only <regex>   Filtert Zielknoten im Abhängigkeits-Listing.
  --fan-in <N>             Zeigt nur Ziele mit mindestens N eingehenden Kanten.
  --help, -h               Hilfe.

Env:
  NO_COLOR=1               Farben aus.

Exit-Codes:
  0  Erfolg
  2  Eingabefehler oder leere/ungültige DOT-Daten
EOF
}

# Parse CLI
POSITIONAL=()
while (( "$#" )); do
  case "${1:-}" in
    --targets-only) shift; TARGETS_ONLY_REGEX="${1:-}"; [[ -z "$TARGETS_ONLY_REGEX" ]] && { echo "Error: --targets-only needs <regex>" >&2; exit 2; } ;;
    --fan-in) shift; FAN_IN_THRESHOLD="${1:-}"; [[ -z "$FAN_IN_THRESHOLD" || ! "$FAN_IN_THRESHOLD" =~ ^[0-9]+$ ]] && { echo "Error: --fan-in needs integer" >&2; exit 2; } ;;
    --help|-h) SHOW_HELP=1 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift || true
done
set -- "${POSITIONAL[@]}"
[[ "$SHOW_HELP" == "1" ]] && { print_help; exit 0; }

# Input handling
TEMP_FILE=false
if [[ ! -t 0 ]]; then
  DOT_FILE=$(mktemp); cat > "$DOT_FILE"; TEMP_FILE=true
elif [[ -n "${1:-}" ]]; then
  DOT_FILE="$1"; [[ ! -f "$DOT_FILE" ]] && { echo "Error: File '$DOT_FILE' not found" >&2; exit 2; }
else
  print_help; exit 2
fi

# Sanity checks
[[ ! -r "$DOT_FILE" ]] && { echo -e "${RED}Error: Cannot read input data${NC}" >&2; exit 2; }
[[ ! -s "$DOT_FILE" ]] && { echo -e "${RED}Error: Input is empty${NC}" >&2; exit 2; }
grep -q '"' "$DOT_FILE" || { echo -e "${RED}Error: Input does not look like DOT (no quoted node ids)${NC}" >&2; exit 2; }

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║               TERRAFORM GRAPH VISUALIZATION              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo
if [[ "$TEMP_FILE" == true ]]; then echo -e "${CYAN}Analyzing: stdin (terraform graph)${NC}"; else echo -e "${CYAN}Analyzing: ${DOT_FILE}${NC}"; fi
echo

# Helpers
fgrep_safe() { grep -F -- "$1" "$2"; }

# Module-Erkennung: erst Cluster, dann Fallback aus Node-IDs
parse_modules() {
  # 1) Cluster-Variante
  local m
  m=$(grep -E 'subgraph[[:space:]]*"?cluster_module\.' "$DOT_FILE" | \
      sed -E 's/.*cluster_([^"[:space:]]*).*/\1/' | sort -u || true)
  if [[ -n "$m" ]]; then printf '%s\n' "$m"; return 0; fi

  # 2) Fallback: aus "module.…" Tokens die längste Modul-Pfad-Präfixmenge extrahieren
  # Beispiel: "module.parent.module.child.resource" -> "module.parent.module.child"
  grep -o '"module\.[^"]*"' "$DOT_FILE" | tr -d '"' | \
    sed -E 's/^(module(\.[^.]+)+)\..*/\1/' | \
    sort -u || true
}

# Data sources robust auf ganzer Zeile
parse_data_sources() {
  grep -o '"data\.[^"]*"' "$DOT_FILE" | tr -d '"' | sort -u
}

# Dependencies robust, kompatibel zu mawk/BusyBox (kein \")
parse_dependencies() {
  awk '
    /->/ {
      line=$0
      if (index(line, "->") == 0) next
      n = split(line, q, /"/)   # split an doppelten Anführungszeichen
      first=""; second=""; count=0
      for (i=2; i<=n; i+=2) {
        if (q[i] == "") continue
        count++
        if (count==1) first=q[i]
        else if (count==2) { second=q[i]; break }
      }
      if (first != "" && second != "") {
        printf("%s|%s\n", first, second)
      }
    }
  ' "$DOT_FILE"
}

extract_resource_name() {
  local full_name="$1"
  if [[ $full_name == module.* ]]; then
    echo "$full_name" | sed 's/module\.[^.]*\.\(.*\)/\1/'
  else
    echo "$full_name"
  fi
}

display_modules() {
  echo -e "${GREEN}TERRAFORM MODULES${NC}"
  echo -e "${GREEN}══════════════════${NC}"
  local modules; modules=$(parse_modules || true)
  if [[ -z "$modules" ]]; then echo -e "${YELLOW}  No modules found${NC}"; echo; return; fi

  while IFS= read -r module; do
    [[ -z "$module" ]] && continue
    echo -e "${CYAN}├─ ${module}${NC}"
    local resources
    resources=$(fgrep_safe "\"${module}." "$DOT_FILE" | sed "s/.*\"${module}\.\([^\"]*\)\".*/\1/" | sort -u || true)
    if [[ -z "$resources" ]]; then echo -e "${CYAN}│  └─ (no resources detected)${NC}"; echo; continue; fi
    local count; count=$(echo "$resources" | wc -l | tr -d ' '); local i=1
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      if [[ $i -eq $count ]]; then echo -e "${CYAN}│  └─ ${r}${NC}"; else echo -e "${CYAN}│  ├─ ${r}${NC}"; fi
      ((i++))
    done <<< "$resources"
    echo
  done <<< "$modules"
}

display_data_sources() {
  echo -e "${PURPLE}DATA SOURCES${NC}"
  echo -e "${PURPLE}═════════════${NC}"
  local ds; ds=$(parse_data_sources || true)
  if [[ -z "$ds" ]]; then echo -e "${YELLOW}  No data sources found${NC}"; echo; return; fi
  while IFS= read -r d; do [[ -z "$d" ]] && continue; echo -e "${PURPLE}├─ ${d}${NC}"; done <<< "$ds"
  echo
}

display_dependencies() {
  echo -e "${YELLOW}🔗 DEPENDENCY RELATIONSHIPS${NC}"
  echo -e "${YELLOW}═══════════════════════════${NC}"
  local deps; deps=$(parse_dependencies || true)
  if [[ -z "$deps" ]]; then echo -e "${YELLOW}  No dependencies found${NC}"; echo; return; fi

  local targets; targets=$(echo "$deps" | cut -d'|' -f2 | sort -u)
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ -n "$TARGETS_ONLY_REGEX" ]] && ! [[ "$target" =~ $TARGETS_ONLY_REGEX ]]; then continue; fi
    local sources; sources=$(echo "$deps" | awk -F'|' -v t="$target" '$2==t {print $1}')
    local n; n=$(echo "$sources" | sed '/^$/d' | wc -l | tr -d ' ')
    if (( FAN_IN_THRESHOLD > 0 )) && (( n < FAN_IN_THRESHOLD )); then continue; fi
    if (( n > 0 )); then
      echo -e "${YELLOW}┌─ ${target}${NC}"
      echo -e "${YELLOW}│  depends on:${NC}"
      local i=1
      while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        if [[ $i -eq $n ]]; then echo -e "${YELLOW}│  └─ ${s}${NC}"; else echo -e "${YELLOW}│  ├─ ${s}${NC}"; fi
        ((i++))
      done <<< "$sources"
      echo -e "${YELLOW}│${NC}"
    fi
  done <<< "$targets"
}

display_stats() {
  echo -e "${BLUE}GRAPH STATISTICS${NC}"
  echo -e "${BLUE}═════════════════${NC}"
  local total_nodes; total_nodes=$(grep -o '"[^"]*"' "$DOT_FILE" | sort -u | wc -l | tr -d ' ' || echo "0")
  local total_edges; total_edges=$(parse_dependencies | wc -l | tr -d ' ' || echo "0")
  local module_count; module_count=$(parse_modules | wc -l | tr -d ' ' || echo "0")
  local data_source_count; data_source_count=$(parse_data_sources | wc -l | tr -d ' ' || echo "0")
  echo -e "${BLUE}├─ Total Nodes: ${total_nodes}${NC}"
  echo -e "${BLUE}├─ Total Edges: ${total_edges}${NC}"
  echo -e "${BLUE}├─ Modules: ${module_count}${NC}"
  echo -e "${BLUE}└─ Data Sources: ${data_source_count}${NC}"
  echo
}

cleanup() { if [[ "$TEMP_FILE" == true && -f "$DOT_FILE" ]]; then rm -f "$DOT_FILE"; fi; }
trap cleanup EXIT

display_stats
display_modules
display_data_sources
display_dependencies

echo -e "${GREEN}Graph visualization complete!${NC}"

