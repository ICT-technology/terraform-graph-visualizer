# Terraform Graph Visualizer

A powerful command-line tool that visualizes Terraform dependency graphs directly in your terminal without requiring GraphViz or external dependencies.

# Terraform Graph Visualizer

A powerful command-line tool that visualizes Terraform dependency graphs directly in your terminal without requiring GraphViz or external dependencies.

## Features

**Terminal-Native Visualization** - No external graph rendering tools required  
**Module Structure Analysis** - Clear overview of all Terraform modules and their resources  
**Data Sources Discovery** - Identifies remote states and external data sources  
**Dependency Mapping** - Shows resource dependencies and relationships  
**Graph Statistics** - Comprehensive metrics about your infrastructure  
**Color-Coded Output** - Easy-to-read colored terminal output  
**Pipe Support** - Works directly with `terraform graph` output  

## Usage

### Method 1: Direct Pipe (Recommended)
```bash
terraform graph | terraform-graph-visualizer.sh
```

### Method 2: From File
```bash
terraform graph > graph.dot
terraform-graph-visualizer.sh graph.dot
```

### Method 3: From Any Directory
```bash
cd /path/to/your/terraform/project
terraform graph | ~/bin/terraform-graph-visualizer.sh
```

## Example Output

```
╔══════════════════════════════════════════════════════════╗
║               TERRAFORM GRAPH VISUALIZATION              ║
╚══════════════════════════════════════════════════════════╝

Analyzing: stdin (terraform graph)

GRAPH STATISTICS
═══════════════════
├─ Total Nodes: 96
├─ Total Edges: 63
├─ Modules: 10
└─ Data Sources: 3

TERRAFORM MODULES
════════════════════
├─ module.vpc
│  ├─ oci_core_vcn.this
│  ├─ oci_core_internet_gateway.this
│  └─ oci_core_nat_gateway.this

├─ module.subnets
│  ├─ oci_core_subnet.public
│  └─ oci_core_subnet.private

DATA SOURCES
═══════════════
├─ data.terraform_remote_state.shared_services
├─ data.terraform_remote_state.networking
└─ data.oci_identity_compartments.root

DEPENDENCY RELATIONSHIPS
═══════════════════════════
┌─ module.vpc.oci_core_vcn.this
│  depends on:
│  ├─ data.terraform_remote_state.shared_services
│  └─ data.oci_identity_compartments.root

Graph visualization complete!
```

## Use Cases

### Infrastructure Analysis
- **Dependency Debugging**: Identify circular dependencies or missing resources
- **Module Assessment**: Understand module complexity and resource distribution  
- **Architecture Review**: Get quick overview of infrastructure components

### CI/CD Integration
```bash
# In your pipeline
terraform init
terraform plan
terraform graph | terraform-graph-visualizer.sh > infrastructure-report.txt
```

### Documentation
- Generate infrastructure overviews for documentation
- Create dependency maps for team knowledge sharing
- Audit infrastructure complexity

## Requirements

- **Bash 4.0+** (most modern Linux distributions)
- **Standard Unix tools**: `grep`, `sed`, `wc`, `sort`, `uniq`
- **Terraform** (for generating graph data)

## Supported Terraform Versions

- Terraform 1.0+ (untested)
- Terraform 1.10+ (latest features)


## Advanced Usage

### Filter Large Outputs
```bash
terraform graph | terraform-graph-visualizer.sh | grep -A 5 "module.database"
```

### Save Analysis Results
```bash
terraform graph | terraform-graph-visualizer.sh > analysis-$(date +%Y%m%d).txt
```

### Combine with Other Tools
```bash
terraform graph | terraform-graph-visualizer.sh | tee infrastructure-overview.txt
```

## Support 
For issues, questions, or contributions, please contact:
- **Author**: Ralf Ramge (ralf.ramge@ict.technology)  
- **Company**: ICT.technology KLG (https://ict.technology)

---

## License

**Business Source License (BSL) - Non-Commercial Use Only**

This software is licensed under the Business Source License. You may use this software for non-commercial purposes only. Commercial use requires a separate license agreement.

For commercial licensing inquiries, please contact: ralf.ramge@ict.technology

```
Business Source License 1.1

Copyright (c) 2025 ICT.technology KLG

Licensed under the Business Source License 1.1 (the "License"); 
you may not use this file except in compliance with the License.

Non-commercial use of this software is permitted.

For commercial use, please contact ralf.ramge@ict.technology
```

The full license text is available at: https://mariadb.com/bsl11/
