FROM archlinux:latest

# System update & base tools
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        base-devel \
        git \
        sudo \
        curl \
        jq \
        openssh \
        github-cli \
    && pacman -Scc --noconfirm

# Non-root build user (makepkg refuses to run as root)
RUN useradd -m -G wheel builduser && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# SSH config for AUR
RUN mkdir -p /home/builduser/.ssh && \
    printf 'Host aur.archlinux.org\n  User aur\n  IdentityFile /home/builduser/.ssh/aur_id_rsa\n  StrictHostKeyChecking no\n' \
        > /home/builduser/.ssh/config && \
    chown -R builduser:builduser /home/builduser/.ssh && \
    chmod 700 /home/builduser/.ssh && \
    chmod 600 /home/builduser/.ssh/config

# Allow git to operate on the mounted workspace
RUN git config --system --add safe.directory '*'

WORKDIR /workspace

# The entrypoint runs as root, sets up the SSH key, then drops to builduser
# for the polling loop.
ENTRYPOINT ["/workspace/scripts/entrypoint.sh"]
