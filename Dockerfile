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
        # webkit2gtk makedepends
        clang \
        cmake \
        gi-docgen \
        glib2-devel \
        gobject-introspection \
        gperf \
        gst-plugins-bad \
        lld \
        ninja \
        python \
        ruby \
        ruby-stdlib \
        systemd \
        unifdef \
        wayland-protocols \
        # webkit2gtk runtime depends
        at-spi2-core \
        atk \
        bubblewrap \
        cairo \
        enchant \
        expat \
        fontconfig \
        freetype2 \
        gdk-pixbuf2 \
        glib2 \
        glibc \
        gst-plugins-bad-libs \
        gst-plugins-base-libs \
        gstreamer \
        gtk3 \
        harfbuzz \
        harfbuzz-icu \
        hyphen \
        icu \
        lcms2 \
        libatomic \
        libavif \
        libdrm \
        libegl \
        libepoxy \
        libgcrypt \
        libgl \
        libjpeg-turbo \
        libjxl \
        libmanette \
        libpng \
        libseccomp \
        libsecret \
        libsoup \
        libsystemd \
        libtasn1 \
        libwebp \
        libx11 \
        libxml2 \
        libxslt \
        mesa \
        openjpeg2 \
        pango \
        sqlite \
        ttf-dejavu \
        wayland \
        woff2 \
        xdg-dbus-proxy \
        zlib \
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
