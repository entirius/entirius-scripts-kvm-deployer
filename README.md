# Entirius KVM Deployer Scripts

Automated deployment scripts for Entirius platform services using KVM virtualization.  
This collection provides tools to quickly deploy and configure virtual machines for various Entirius components.

## Overview

**Entirius** is an open-source AI-powered e-commerce platform that simplifies online store creation and management through automation and intelligent tools. The platform focuses on simplicity (KISS Principle) and full transparency through community-driven development.

This repository contains deployment automation scripts that follow Entirius [ADR-017: KVM Virtualization for Service Hosting](https://docs.entirius.com/development/adr/) architectural decision.

## Available Deployments

### n8n Business Process Automation

Automated deployment of n8n workflow automation platform for business process automation ([ADR-014](https://docs.entirius.com/development/adr/)).

**Files:**
- `n8n-deploy.sh` - Main deployment script
- `n8n-deploy.config.example` - Configuration template
- `templates/n8n/user_data_template.yaml.tpl` - Cloud-init template

## Documentation

For comprehensive documentation, visit the official Entirius documentation:

- **Main Documentation:** [docs.entirius.com](https://docs.entirius.com/)
- **KVM Server Installation:** [Server KVM Install Guide](https://docs.entirius.com/devops/installation/server-kvm-install/)
- **n8n Deployment Procedure:** [n8n Deployment Guide](https://docs.entirius.com/devops/installation/n8n-deployment/)
- **Architecture Decisions:** [ADR Documentation](https://docs.entirius.com/development/adr/)

### Getting Help

If you encounter issues:

1. Check the [official documentation](https://docs.entirius.com/)
2. Review the [n8n deployment guide](https://docs.entirius.com/devops/installation/n8n-deployment/)

## Related Projects

- **Technical Documentation:** [docs.entirius.com](https://docs.entirius.com/)

---

**Entirius** - Simplifying e-commerce through AI-powered automation and open-source transparency.
