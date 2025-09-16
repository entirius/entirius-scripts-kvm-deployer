# Wymagania instalacyjne entirius-scripts-kvm-deployer

## Wymagania systemowe

### System operacyjny
- **Ubuntu 24.04** (host z KVM/libvirt)
- Dostęp do internetu do pobierania pakietów

### Wymagane narzędzia i pakiety

#### Podstawowe pakiety systemowe
```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst guestfs-tools gettext-base
```

#### Szczegółowe wymagania pakietów:
- **qemu-kvm** - główna platforma wirtualizacji KVM
- **libvirt-daemon-system** - daemon zarządzania maszynami wirtualnymi
- **virtinst** - narzędzia do instalacji maszyn wirtualnych (`virt-install`)
- **guestfs-tools** - narzędzia do modyfikacji obrazów VM (`virt-customize`)
- **gettext-base** - zawiera `envsubst` do przetwarzania szablonów

#### Uprawnienia użytkownika
```bash
sudo usermod -a -G libvirt $(whoami)
# Wyloguj się i zaloguj ponownie lub uruchom:
newgrp libvirt
```

### Obraz bazowy Ubuntu Cloud
```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
```

### Klucze SSH
Wymagany jest klucz SSH do dostępu do tworzonych maszyn wirtualnych:
```bash
# Jeśli nie masz kluczy SSH:
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

## Konfiguracja środowiska

### Ścieżki przechowywania
- **Domyślna ścieżka VM**: `/var/lib/libvirt/images`
- **Pliki robocze**: bieżący katalog roboczy

### Wymagane uprawnienia
- Użytkownik musi należeć do grupy `libvirt`
- Dostęp do `sudo` dla operacji `virt-customize`
- Uprawnienia zapisu w `/var/lib/libvirt/images`

### Konfiguracja sieci
- Sieć libvirt `default` musi być aktywna
- Domyślnie używa NAT/bridge networking

## Pliki projektu

### Skrypty wykonywalne
Po pobraniu plików ustaw uprawnienia wykonywalne:
```bash
chmod +x create_template_script.sh n8n-deploy.sh setup_n8n_script.sh
```

### Struktura plików
```
entirius-scripts-kvm-deployer/
├── create_template_script.sh          # Tworzenie szablonu VM
├── n8n-deploy.sh                     # Wdrażanie instancji klientów
├── n8n-deploy.config.example         # Przykład pliku konfiguracyjnego
├── setup_n8n_script.sh              # Konfiguracja n8n
├── templates/
│   └── n8n/
│       ├── user_data_template.txt    # Szablon cloud-init
│       ├── n8n_service_template.txt  # Szablon usługi systemd
│       └── nginx_config_template.txt # Szablon konfiguracji nginx
└── ubuntu-24.04-server-cloudimg-amd64.img  # Obraz bazowy Ubuntu (opcjonalny)
```

## Parametry konfiguracyjne

### Konfiguracja w pliku `n8n-deploy.config`:

Skopiuj i edytuj plik konfiguracyjny:
```bash
cp n8n-deploy.config.example n8n-deploy.config
vim n8n-deploy.config
```

Dostępne parametry konfiguracyjne:
```bash
# Konfiguracja domeny
DOMAIN="yourdomain.com"           # Twoja domena

# Konfiguracja VM
TEMPLATE_IMAGE="n8n-template.img" # Ścieżka obrazu szablonu
VM_STORAGE_PATH="/var/lib/libvirt/images" # Lokalizacja przechowywania VM
VM_MEMORY=1024                    # Pamięć RAM w MB
VM_VCPUS=1                       # Liczba CPU

# Konfiguracja SSH
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub" # Ścieżka do klucza publicznego SSH
```

## Zasoby systemowe

### Specyfikacje VM
- **Pamięć**: 1024 MB (domyślnie, konfigurowalne)
- **CPU**: 1 vCPU (domyślnie, konfigurowalne)
- **Dysk**: ~2-3GB na podstawie rozmiaru szablonu
- **Sieć**: Bridge/NAT (domyślna sieć libvirt)

### Wymagania dyskowe
- **Szablon VM**: ~2-3GB
- **Każda instancja klienta**: ~2-3GB
- **Miejsce robocze**: dodatkowe 1GB na pliki tymczasowe

## Składniki oprogramowania w VM

### Automatycznie instalowane w szablonie:
- **Node.js 20.x** - środowisko uruchomieniowe dla n8n
- **n8n** - platforma automatyzacji workflow
- **PM2** - manager procesów Node.js
- **nginx** - serwer web/reverse proxy
- **Pakiety systemowe**: curl, wget, gnupg

### Konfiguracje bezpieczeństwa:
- **UFW firewall** - porty 22, 80, 443
- **Klucze SSH** - wyłącznie autoryzacja kluczami
- **Nagłówki bezpieczeństwa nginx** - X-Frame-Options, CSP
- **Izolacja usług** - dedykowany użytkownik `n8n`

## Weryfikacja instalacji

### Sprawdzenie wymagań:
```bash
# Sprawdź KVM
kvm-ok

# Sprawdź libvirt
sudo systemctl status libvirtd

# Sprawdź narzędzia
which virt-install virt-customize envsubst

# Sprawdź sieć
sudo virsh net-list --all
```

### Test podstawowej funkcjonalności:
```bash
# Lista VM
virsh list --all

# Informacje o sieci DHCP
virsh net-dhcp-leases default
```

## Integracja z WebVirtCloud

System jest w pełni kompatybilny z WebVirtCloud do scentralizowanego zarządzania:
- **Automatyczne wykrywanie VM** - wszystkie VM pojawią się z właściwym nazewnictwem
- **Dostęp do konsoli** - konsola VNC przez interfejs web
- **Zarządzanie zasilaniem** - start/stop/restart przez WebVirtCloud
- **Monitorowanie** - monitorowanie wykorzystania zasobów

## Wsparcie i rozwiązywanie problemów

### Logi systemowe:
- **Cloud-init**: `/var/log/cloud-init-output.log` (w VM)
- **n8n service**: `sudo journalctl -u n8n -f` (w VM)
- **nginx**: `/var/log/nginx/` (w VM)

### Diagnostyka:
- **Status VM**: `virsh list --all`
- **Konsola VM**: `virsh console vm-name`
- **Adres IP**: `virsh net-dhcp-leases default`