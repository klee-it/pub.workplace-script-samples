# pub.workplace-script-samples

A curated collection of deployment, configuration, and monitoring scripts for managing workplace endpoints across Windows, macOS, Linux, and virtualization platforms. These samples emphasize repeatable operations, safe rollouts, and automated remediation for both on-premises and cloud environments.

---

## 🚀 Features

- **Provisioning & Enrollment:** Automated device onboarding, Autopilot-ready flows, and post-enrollment setup.
- **Software Management:** Distribution, updates, and lifecycle management.
- **Configuration & Compliance:** Baselines, policy enforcement, and security hardening.
- **Monitoring & Remediation:** Health checks, logging, inventory, and self-healing scripts.

---

## 📁 What’s in the Repository

```
.
├── grafana/        # Dashboard examples and configurations
├── intune/         # Configuration, compliance and remediation scripts
├── jamf/           # Configuration scripts
├── powershell/     # Extensive PowerShell functions for use in CLI, scripts, and modules
├── prometheus/     # Alerting rule examples
├── proxmox/        # Automation scripts
├── ubuntu/         # Automation scripts
└── windows/        # Automation scripts
```

---

## 🛠️ Supported Platforms & Tools

- **Operating Systems:** Windows 10/11, Windows Server, Linux (Ubuntu), macOS
- **Management:** Microsoft Intune, Jamf Pro, Proxmox
- **Automation:** PowerShell, Bash, WinGet
- **Monitoring:** Grafana, Prometheus

---

## 📝 How to Use
1. **Review** each script’s header comments for prerequisites and required parameters.
2. **Test** scripts in a lab or pilot environment before deploying to production.
3. These scripts are made for:
    - Repeatable, automated operations
    - Safe rollouts with minimal disruption
    - Easy troubleshooting and remediation
    - Can be run multiple times safely without causing problems
    - Structured logging and clear exit codes

---

## 📄 License

This repository uses the MIT License. See the [LICENSE](LICENSE) file for details.
