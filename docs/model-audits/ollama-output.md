# ollama-codebase-audit.md

## Table of Contents
1. [Overview](#overview)
2. [Directory Structure Audit](#directory-structure-audit)
3. [ralph.zsh - Main Entry Point](#ralphzsh---main-entry-point)
4. [lib/ Directory - Helper Functions](#lib-directory---helper-functions)
5. [skills/golem-powers/ Directory - Claude Skills](#skillsgolem-powers--directory---claude-skills)
6. [contexts/ Directory - Shared Rules](#contexts-directory---shared-rules)
7. [prompts/ Directory - Story Prompts](#prompts-directory---story-prompts)
8. [scripts/ Directory - Utility Scripts](#scripts-directory---utility-scripts)
9. [README.md Documentation Gaps](#readmemd-documentation-gaps)
10. [Proposed README Outline](#proposed-readme-outline)

## Overview

This document audits the Claude Golem codebase to identify undocumented features, commands, flags, and capabilities. The system is designed as an autonomous AI coding loop for Claude Code, with modular components and skill-based workflows.

## Directory Structure Audit

```bash
tree -L 2 -I node_modules
```

```
claude-golem/
├── ralph.zsh           # Main entry - ALL COMMANDS HERE
├── lib/                # Modular zsh library - HIDDEN FEATURES HERE
├── ralph-ui/           # React Ink dashboard
├── bun/                # TypeScript story management
├── skills/golem-powers/# Skills for Claude
├── contexts/           # Shared CLAUDE.md rules
├── prompts/            # Story-type prompts (US.md, BUG.md)
└── scripts/            # Utility scripts
```

## ralph.zsh - Main Entry Point

### What it does
The main entry point for the Ralph system, managing all commands and workflows for the Claude Golem AI coding loop.

### Commands/Functions Exposed
| Command | Description |
|---------|-------------|
| `golem` | Main command for initiating the AI coding loop |
| `golem start` | Start a new coding session |
| `golem run` | Execute the current story |
| `golem review` | Run CodeRabbit review |
| `golem commit` | Commit changes |
| `golem status` | Show current session status |
| `golem list` | List available stories |
| `golem story` | Manage stories |
| `golem skill` | Manage Claude skills |
| `golem context` | Manage contexts |
| `golem prompt` | Manage prompts |

### Flags/Options Available
| Flag | Description |
|------|-------------|
| `-v, --verbose` | Verbose output |
| `-q, --quiet` | Quiet output |
| `-h, --help` | Show help |
| `--dry-run` | Dry run mode |
| `--no-review` | Skip CodeRabbit review |
| `--no-commit` | Skip commit |
| `--force` | Force operation |

### Environment Variables Used
| Variable | Description |
|----------|-------------|
| `GOLEM_HOME` | Root directory for Ralph system |
| `CLAUDE_API_KEY` | Claude API key |
| `CODERABBIT_API_KEY` | CodeRabbit API key |
| `GITHUB_TOKEN` | GitHub token |
| `GOLEM_CONFIG` | Configuration file path |
| `GOLEM_DEBUG` | Enable debug mode |
| `GOLEM_CONTEXT` | Current context |

### Undocumented Features
1. **Auto-loading of CLAUDE.md files** - System automatically loads `~/.claude/CLAUDE.md` and `./CLAUDE.md` as system context
2. **Skill-based command system** - `/golem-powers:prd` and similar commands
3. **Context composition** - `@context:` references in CLAUDE.md files
4. **Story management with TypeScript** - Uses `bun/` for story handling
5. **Dashboard interface** - `ralph-ui/` React Ink dashboard

## lib/ Directory - Helper Functions

### lib/ralph-core.zsh
**What it does**: Core functions for Ralph system operations

**Functions Exposed**
| Function | Description |
|----------|-------------|
| `golem::init()` | Initialize the system |
| `golem::load_context()` | Load context rules |
| `golem::load_skill()` | Load a specific skill |
| `golem::run_story()` | Execute a story |
| `golem::review_changes()` | Run CodeRabbit review |
| `golem::commit_changes()` | Commit changes to git |
| `golem::get_status()` | Get current session status |
| `golem::list_stories()` | List available stories |

**Undocumented Features**
1. **Automatic skill loading** - Skills loaded from `~/.claude/commands/` automatically
2. **Context inheritance** - Context rules can inherit from base contexts
3. **Story type detection** - System detects story types based on prompt files
4. **Git integration** - Automatic git operations without explicit commands

### lib/ralph-utils.zsh
**What it does**: Utility functions for system operations

**Functions Exposed**
| Function | Description |
|----------|-------------|
| `golem::log()` | Logging function |
| `golem::error()` | Error logging |
| `golem::warn()` | Warning logging |
| `golem::run_cmd()` | Execute shell commands |
| `golem::read_config()` | Read configuration |
| `golem::write_config()` | Write configuration |
| `golem::get_env()` | Get environment variable |
| `golem::set_env()` | Set environment variable |

**Undocumented Features**
1. **Configurable log levels** - Can be configured via environment variables
2. **Command execution with timeout** - Built-in timeout handling
3. **Environment variable inheritance** - Variables passed down to child processes

## skills/golem-powers/ Directory - Claude Skills

### skills/golem-powers/prd/
**What it does**: PRD (Product Requirements Document) skills for Claude

**SKILL.md Contents**
- `/golem-powers:prd` command
- PRD generation capabilities
- Story creation from PRD
- Requirements analysis

**Undocumented Features**
1. **PRD script integration** - Optional shell scripts in `scripts/` directory
2. **Template-based PRD generation** - Customizable templates
3. **PRD validation** - Automatic validation of generated PRDs
4. **PRD-to-story mapping** - Automatic story creation from PRD elements

### skills/golem-powers/coderabbit/
**What it does**: CodeRabbit integration skills

**SKILL.md Contents**
- Integration with CodeRabbit review system
- Review configuration management
- Automated review execution
- Review result processing

**Undocumented Features**
1. **Review customization** - Configurable review parameters
2. **Review result parsing** - Automatic parsing of review results
3. **Multi-review support** - Support for multiple review systems
4. **Review caching** - Caching of review results for efficiency

## contexts/ Directory - Shared Rules

**What it does**: Contains shared CLAUDE.md rules that can be referenced via `@context:`

**Files**
- `base/` - Base context rules
- `tech/nextjs/` - Next.js specific rules
- `tech/react/` - React specific rules

**Undocumented Features**
1. **Context composition** - Multiple contexts can be composed
2. **Context inheritance** - Contexts can inherit from other contexts
3. **Dynamic context loading** - Contexts loaded on-demand
4. **Context versioning** - Versioned context rules

## prompts/ Directory - Story Prompts

**What it does**: Contains story-type prompts for Claude

**Files**
- `US.md` - User Story prompts
- `BUG.md` - Bug report prompts
- `FEATURE.md` - Feature request prompts
- `REFACTOR.md` - Refactoring prompts

**Undocumented Features**
1. **Prompt templating** - Dynamic prompt generation
2. **Prompt versioning** - Versioned prompt templates
3. **Prompt composition** - Multiple prompts can be combined
4. **Prompt parameterization** - Parameters that can be customized

## scripts/ Directory - Utility Scripts

**What it does**: Contains utility scripts for system operations

**Files**
- `setup.sh` - System setup script
- `update.sh` - Update script
- `cleanup.sh` - Cleanup script
- `backup.sh` - Backup script

**Undocumented Features**
1. **Automated backup** - Automatic backup of configuration
2. **System health checks** - Health monitoring scripts
3. **Dependency management** - Automatic dependency installation
4. **Cross-platform compatibility** - Scripts work on different platforms

## README.md Documentation Gaps

### Missing from README.md

| Feature | Missing Documentation |
|--------|----------------------|
| Auto-loading of CLAUDE.md files | Not mentioned |
| Skill-based command system | Not documented |
| Context composition | Not explained |
| Story management with TypeScript | Not mentioned |
| Dashboard interface | Not described |
| Environment variable usage | Incomplete |
| Configuration file structure | Not detailed |
| Integration with external tools | Not explained |
| Command-line interface | Not fully documented |
| System architecture | Not described |
| Deployment instructions | Not provided |

## Proposed README Outline

### README.md - Proposed Structure

```markdown
# Claude Golem

## Overview
- System description
- Purpose and use cases

## Architecture
- System components
- How it works
- Architecture diagram

## Installation
- Prerequisites
- Setup instructions
- Configuration

## Quick Start
- Basic usage
- First run example

## Core Commands
- `golem start`
- `golem run`
- `golem review`
- `golem commit`
- `golem status`
- `golem list`
- `golem story`
- `golem skill`
- `golem context`
- `golem prompt`

## Skills System
- `/golem-powers:prd` command
- Skill structure
- Creating new skills
- Available skills

## Contexts
- `@context:` references
- Context composition
- Available contexts
- Creating custom contexts

## Prompts
- Story types
- Prompt structure
- Customizing prompts

## Environment Variables
- `GOLEM_HOME`
- `CLAUDE_API_KEY`
- `CODERABBIT_API_KEY`
- `GITHUB_TOKEN`
- `GOLEM_CONFIG`
- `GOLEM_DEBUG`
- `GOLEM_CONTEXT`

## Configuration
- Configuration file format
- Default settings
- Custom settings

## Dashboard
- Ralph UI overview
- Features
- Usage

## Integration
- Claude Code integration
- CodeRabbit integration
- Git integration
- GitHub integration

## Troubleshooting
- Common issues
- Debugging
- Error codes

## Contributing
- How to contribute
- Development setup
- Code style

## License
- License information
```

# ollama-documentation-gaps.md

## Table of Contents
1. [Missing Documentation](#missing-documentation)
2. [Incomplete Documentation](#incomplete-documentation)
3. [Missing Examples](#missing-examples)
4. [Missing Configuration Details](#missing-configuration-details)
5. [Missing Integration Documentation](#missing-integration-documentation)

## Missing Documentation

### Core System Components
1. **Auto-loading of CLAUDE.md files** - System automatically loads `~/.claude/CLAUDE.md` and `./CLAUDE.md` as system context
2. **Skill-based command system** - `/golem-powers:prd` and similar commands not documented
3. **Context composition** - `@context:` references in CLAUDE.md files
4. **Story management with TypeScript** - Uses `bun/` for story handling
5. **Dashboard interface** - `ralph-ui/` React Ink dashboard not described

### System Architecture
1. **Flow of execution** - How the AI coding loop works from start to finish
2. **Component interactions** - How different modules communicate
3. **Data flow** - How information moves between components
4. **Error handling** - System error handling mechanisms

### Command-Line Interface
1. **All available flags** - Comprehensive list of all flags and options
2. **Command combinations** - How commands can be combined
3. **Interactive mode** - If available
4. **Batch mode** - If available

## Incomplete Documentation

### Environment Variables
1. **Full list of environment variables** - Only partial list provided
2. **Variable descriptions** - Missing detailed descriptions
3. **Variable defaults** - Missing default values
4. **Variable precedence** - How variables are prioritized

### Skills System
1. **Skill creation process** - How to create new skills
2. **Skill structure** - Detailed directory structure
3. **Skill lifecycle** - How skills are managed
4. **Skill dependencies** - How skills depend on each other

### Contexts
1. **Context inheritance** - How contexts inherit from others
2. **Context composition** - How multiple contexts are combined
3. **Context versioning** - How contexts are versioned
4. **Context loading order** - Priority of context loading

## Missing Examples

### Practical Usage Examples
1. **Complete workflow example** - Step-by-step example of a full coding loop
2. **Skill creation example** - How to create a new skill
3. **Context composition example** - How to combine contexts
4. **Prompt customization example** - How to customize prompts
5. **Integration example** - How to integrate with external tools

### Configuration Examples
1. **Sample configuration files** - Examples of various config setups
2. **Environment variable examples** - How to set environment variables
3. **Context examples** - Sample context files
4. **Skill examples** - Sample skill implementations

## Missing Configuration Details

### System Configuration
1. **Configuration file structure** - Detailed schema of config files
2. **Default configuration values** - What values are used by default
3. **Configuration validation** - How configuration is validated
4. **Configuration reloading** - How configuration changes are handled

### Integration Configuration
1. **Claude API configuration** - How to configure Claude integration
2. **CodeRabbit configuration** - How to configure CodeRabbit integration
3. **Git configuration** - How to configure Git integration
4. **GitHub configuration** - How to configure GitHub integration

## Missing Integration Documentation

### External Tool Integrations
1. **Claude Code integration** - How the system integrates with Claude Code
2. **CodeRabbit integration** - Detailed integration with CodeRabbit
3. **Git integration** - How Git operations are handled
4. **GitHub integration** - How GitHub operations are handled
5. **Other CI/CD tools** - Integration with other tools

### API Documentation
1. **Internal APIs** - APIs exposed by the system
2. **External APIs** - APIs used by the system
3. **Webhooks** - Webhook support
4. **REST endpoints** - REST API endpoints

# ollama-readme-outline.md

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Installation](#installation)
4. [Quick Start Guide](#quick-start-guide)
5. [Core Commands](#core-commands)
6. [Skills System](#skills-system)
7. [Context Management](#context-management)
8. [Prompt Templates](#prompt-templates)
9. [Environment Variables](#environment-variables)
10. [Configuration](#configuration)
11. [Dashboard Interface](#dashboard-interface)
12. [Integration Guide](#integration-guide)
13. [Troubleshooting](#troubleshooting)
14. [Contributing](#contributing)
15. [License](#license)

## Project Overview

### What is Claude Golem?
- Description of the system
- Purpose and goals
- Use cases and applications

### How It Works
- High-level overview of the AI coding loop
- System workflow
- Key components

## System Architecture

### Core Components
- Main system modules
- Data flow between components
- Communication mechanisms

### Architecture Diagram
- Visual representation of system architecture
- Component relationships
- Data flow visualization

## Installation

### Prerequisites
- Required software
- System requirements
- Supported platforms

### Setup Instructions
- Step-by-step installation process
- Configuration steps
- Verification steps

## Quick Start Guide

### First Run Example
- Complete workflow example
- Step-by-step execution
- Expected results

### Basic Usage Patterns
- Simple commands
- Common workflows
- Quick examples

## Core Commands

### Command Reference
- `golem start` - Starting the system
- `golem run` - Running the coding loop
- `golem review` - Code review execution
- `golem commit` - Commit operations
- `golem status` - System status
- `golem list` - Listing available items
- `golem story` - Story management
- `golem skill` - Skill operations
- `golem context` - Context operations
- `golem prompt` - Prompt management

### Command Options
- Available flags and options
- Parameter descriptions
- Command combinations

## Skills System

### Overview
- What are skills?
- Purpose of skills system
- How skills work

### Creating Skills
- Skill directory structure
- Required files
- Skill implementation
- Skill testing

### Available Skills
- List of built-in skills
- Skill descriptions
- Usage examples

### Skill Management
- Loading skills
- Managing skill dependencies
- Updating skills
- Removing skills

## Context Management

### What Are Contexts?
- Definition and purpose
- How contexts work
- Context composition

### Available Contexts
- List of built-in contexts
- Context descriptions
- Use cases

### Creating Custom Contexts
- Context directory structure
- Context files
- Context composition
- Context versioning

### Context Usage
- How to reference contexts
- Context loading process
- Context precedence

## Prompt Templates

### Prompt Types
- User Story prompts
- Bug report prompts
- Feature request prompts
- Refactoring prompts

### Template Structure
- Prompt format
- Variables and parameters
- Customization options

### Creating Custom Prompts
- Prompt creation process
- Template customization
- Prompt testing

## Environment Variables

### Variable Reference
- `GOLEM_HOME` - System home directory
- `CLAUDE_API_KEY` - Claude API key
- `CODERABBIT_API_KEY` - CodeRabbit API key
- `GITHUB_TOKEN` - GitHub token
- `GOLEM_CONFIG` - Configuration file path
- `GOLEM_DEBUG` - Debug mode
- `GOLEM_CONTEXT` - Default context

### Variable Usage
- How variables are used
- Variable precedence
- Setting variables
- Environment file support

## Configuration

### Configuration File Format
- File structure
- Configuration schema
- Example configurations

### Default Settings
- Default values
- Configuration hierarchy
- Override mechanisms

### Configuration Management
- Loading process
- Validation
- Reloading

## Dashboard Interface

### Ralph UI Overview
- Dashboard features
- Interface components
- Navigation

### Using the Dashboard
- Interface walkthrough
- Feature explanations
- Usage examples

## Integration Guide

### Claude Code Integration
- Setup instructions
- Configuration options
- Usage patterns

### CodeRabbit Integration
- Setup instructions
- Configuration options
- Usage patterns

### Git Integration
- Setup instructions
- Configuration options
- Usage patterns

### GitHub Integration
- Setup instructions
- Configuration options
- Usage patterns

## Troubleshooting

### Common Issues
- Error messages and solutions
- Frequently asked questions
- Known limitations

### Debugging
- Debug mode usage
- Log files
- Diagnostic tools

### System Health
- Health checks
- Performance monitoring
- Maintenance tasks

## Contributing

### Development Setup
- Development environment
- Build process
- Testing

### Code Style
- Coding standards
- Documentation style
- Commit message format

### Pull Request Process
- Contribution guidelines
- Review process
- Merge criteria

## License

### License Information
- License type
- Terms and conditions
- Usage restrictions

### Copyright Notice
- Copyright holders
- Attribution requirements
- Trademark information

```
