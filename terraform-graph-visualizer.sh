#!/bin/bash
# scripts/check-module-versions.sh
#
# Copyright (c) 2025 ICT.technology KLG (https://ict.technology)
# Author: Ralf Ramge (ralf.ramge@ict.technology)
# License: unrestricted non-commercial use (Business Source License 1.0)

set -euo pipefail

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if input comes from stdin (pipe) or file argument
if [[ ! -t 0 ]]; then
    # Input from stdin (pipe)
    DOT_FILE=$(mktemp)
    cat > "$DOT_FILE"
    TEMP_FILE=true
elif [[ -n "${1:-}" ]]; then
    # Input from file argument
    DOT_FILE="$1"
    TEMP_FILE=false
    if [[ ! -f "$DOT_FILE" ]]; then
        echo "Error: File '$DOT_FILE' not found"
        echo "Usage: $0 <dot-file>"
        echo "   or: terraform graph | $0"
        exit 1
    fi
else
    # No input provided
    echo "Usage: $0 <dot-file>"
    echo "   or: terraform graph | $0"
    echo "Examples:"
    echo "  $0 graph.dot"
    echo "  terraform graph | $0"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║               TERRAFORM GRAPH VISUALIZATION              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Parse modules from clusters
parse_modules() {
    grep -E 'subgraph "cluster_' "$DOT_FILE" | \
    sed 's/.*cluster_\([^"]*\)".*/\1/' | \
    sort | uniq
}

# Parse data sources
parse_data_sources() {
    grep -E '^\s*"data\.' "$DOT_FILE" | \
    sed 's/.*"\(data\.[^"]*\)".*/\1/' | \
    sort | uniq
}

# Parse dependencies (arrows)
parse_dependencies() {
    grep -E ' -> ' "$DOT_FILE" | \
    sed 's/^\s*"\([^"]*\)" -> "\([^"]*\)";$/\1|\2/'
}

# Extract resource name without module prefix
extract_resource_name() {
    local full_name="$1"
    if [[ $full_name == module.* ]]; then
        echo "$full_name" | sed 's/module\.[^.]*\.\(.*\)/\1/'
    else
        echo "$full_name"
    fi
}

# Display modules structure
display_modules() {
    echo -e "${GREEN}TERRAFORM MODULES${NC}"
    echo -e "${GREEN}══════════════════${NC}"
    
    local modules
    modules=$(parse_modules)
    
    if [[ -z "$modules" ]]; then
        echo -e "${YELLOW}  No modules found${NC}"
        return
    fi
    
    while IFS= read -r module; do
        echo -e "${CYAN}├─ ${module}${NC}"
        
        # Find resources in this module
        local resources
        resources=$(grep -E "\"${module}\." "$DOT_FILE" | \
                   sed "s/.*\"${module}\.\([^\"]*\)\".*/\1/" | \
                   sort | uniq)
        
        local resource_count
        resource_count=$(echo "$resources" | wc -l)
        local counter=1
        
        while IFS= read -r resource; do
            if [[ $counter -eq $resource_count ]]; then
                echo -e "${CYAN}│  └─ ${resource}${NC}"
            else
                echo -e "${CYAN}│  ├─ ${resource}${NC}"
            fi
            ((counter++))
        done <<< "$resources"
        echo
    done <<< "$modules"
}

# Display data sources
display_data_sources() {
    echo -e "${PURPLE}DATA SOURCES${NC}"
    echo -e "${PURPLE}═════════════${NC}"
    
    local data_sources
    data_sources=$(parse_data_sources)
    
    if [[ -z "$data_sources" ]]; then
        echo -e "${YELLOW}  No data sources found${NC}"
        return
    fi
    
    while IFS= read -r ds; do
        echo -e "${PURPLE}├─ ${ds}${NC}"
    done <<< "$data_sources"
    echo
}

# Display dependency tree
display_dependencies() {
    echo -e "${YELLOW}🔗 DEPENDENCY RELATIONSHIPS${NC}"
    echo -e "${YELLOW}═══════════════════════════${NC}"
    
    local deps
    deps=$(parse_dependencies)
    
    if [[ -z "$deps" ]]; then
        echo -e "${YELLOW}  No dependencies found${NC}"
        return
    fi
    
    # Group by target (what depends on what)
    local targets
    targets=$(echo "$deps" | cut -d'|' -f2 | sort | uniq)
    
    while IFS= read -r target; do
        local sources
        sources=$(echo "$deps" | grep "|${target}$" | cut -d'|' -f1)
        local source_count
        source_count=$(echo "$sources" | wc -l)
        
        if [[ $source_count -gt 0 ]]; then
            echo -e "${YELLOW}┌─ ${target}${NC}"
            echo -e "${YELLOW}│  depends on:${NC}"
            
            local counter=1
            while IFS= read -r source; do
                if [[ $counter -eq $source_count ]]; then
                    echo -e "${YELLOW}│  └─ ${source}${NC}"
                else
                    echo -e "${YELLOW}│  ├─ ${source}${NC}"
                fi
                ((counter++))
            done <<< "$sources"
            echo -e "${YELLOW}│${NC}"
        fi
    done <<< "$targets"
}

# Display graph statistics
display_stats() {
    echo -e "${BLUE}GRAPH STATISTICS${NC}"
    echo -e "${BLUE}═════════════════${NC}"
    
    local total_nodes
    total_nodes=$(grep -c '^\s*"[^"]*"' "$DOT_FILE" || echo "0")
    
    local total_edges
    total_edges=$(grep -c ' -> ' "$DOT_FILE" || echo "0")
    
    local module_count
    module_count=$(parse_modules | wc -l)
    
    local data_source_count
    data_source_count=$(parse_data_sources | wc -l)
    
    echo -e "${BLUE}├─ Total Nodes: ${total_nodes}${NC}"
    echo -e "${BLUE}├─ Total Edges: ${total_edges}${NC}"
    echo -e "${BLUE}├─ Modules: ${module_count}${NC}"
    echo -e "${BLUE}└─ Data Sources: ${data_source_count}${NC}"
    echo
}

# Cleanup function for temporary files
cleanup() {
    if [[ "$TEMP_FILE" == true && -f "$DOT_FILE" ]]; then
        rm -f "$DOT_FILE"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    if [[ "$TEMP_FILE" == true ]]; then
        echo -e "${CYAN}Analyzing: stdin (terraform graph)${NC}"
    else
        echo -e "${CYAN}Analyzing: ${DOT_FILE}${NC}"
    fi
    echo
    
    display_stats
    display_modules
    display_data_sources
    display_dependencies
    
    echo -e "${GREEN}Graph visualization complete!${NC}"
}

# Check if dot file is readable
if [[ ! -r "$DOT_FILE" ]]; then
    echo -e "${RED}Error: Cannot read input data${NC}" >&2
    exit 1
fi

main
