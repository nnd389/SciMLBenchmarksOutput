---
author: "Gen Kuroki (黒木玄), Chris Rackauckas"
title: "Single Pedulum Comparison"
---


# Solving single pendulums by DifferentialEquations.jl

In this notebook, we shall solve the single pendulum equation:

$$\ddot q = -\sin q,$$

where $q$ means the angle.

Hamiltonian:

$$H(q,p) = \frac{1}{2}p^2 - \cos q + 1.$$

Canonical equation:

$$\dot q = p, \quad \dot p = - \sin q.$$

Initial condition:

$$q(0) = 0, \quad p(0) = 2k.$$

Exact solution:

$$q(t) = 2\arcsin(k\,\mathrm{sn}(t,k)).$$

Maximum of $q(t)$:

$$\sin(q_{\max}/2) = k, \quad q_{\max} = \max\{q(t)\}.$$

Define $y(t)$ by

$$y(t) = \sin(q(t)/2) = k\,\mathrm{sn}(t,k), \quad y_{\max} = k.$$

```julia
# Single pendulums shall be solved numerically.
#
using OrdinaryDiffEq, Elliptic, Printf, DiffEqPhysics, Statistics

sol2q(sol) = [sol.u[i][j] for i in 1:length(sol.u), j in 1:length(sol.u[1])÷2]
sol2p(sol) = [sol.u[i][j] for i in 1:length(sol.u), j in length(sol.u[1])÷2+1:length(sol.u[1])]
sol2tqp(sol) = (sol.t, sol2q(sol), sol2p(sol))

# The exact solutions of single pendulums can be expressed by the Jacobian elliptic functions.
#
sn(u, k) = Jacobi.sn(u, k^2) # the Jacobian sn function

# Use PyPlot.
#
using PyPlot

colorlist = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
]
cc(k) = colorlist[mod1(k, length(colorlist))]

# plot the sulution of a Hamiltonian problem
#
function plotsol(sol::ODESolution)
    local t, q, p
    t, q, p = sol2tqp(sol)
    local d = size(q)[2]
    for j in 1:d
        j_str = d > 1 ? "[$j]" : ""
        plot(t, q[:,j], color=cc(2j-1), label="q$(j_str)", lw=1)
        plot(t, p[:,j], color=cc(2j),   label="p$(j_str)", lw=1, ls="--")
    end
    grid(ls=":")
    xlabel("t")
    legend()
end

# plot the solution of a Hamiltonian problem on the 2D phase space
#
function plotsol2(sol::ODESolution)
    local t, q, p
    t, q, p = sol2tqp(sol)
    local d = size(q)[2]
    for j in 1:d
        j_str = d > 1 ? "[$j]" : ""
        plot(q[:,j], p[:,j], color=cc(j), label="(q$(j_str),p$(j_str))", lw=1)
    end
    grid(ls=":")
    xlabel("q")
    ylabel("p")
    legend()
end

# plot the energy of a Hamiltonian problem
#
function plotenergy(H, sol::ODESolution)
    local t, q, p
    t, q, p = sol2tqp(sol)
    local energy = [H(q[i,:], p[i,:], nothing) for i in 1:size(q)[1]]
    plot(t, energy, label="energy", color="red", lw=1)
    grid(ls=":")
    xlabel("t")
    legend()
    local stdenergy_str = @sprintf("%.3e", std(energy))
    title("                    std(energy) = $stdenergy_str", fontsize=10)
end

# plot the numerical and exact solutions of a single pendulum
#
# Warning: Assume q(0) = 0, p(0) = 2k.   (for the sake of laziness)
#
function plotcomparison(k, sol::ODESolution)
    local t, q, p
    t, q, p = sol2tqp(sol)
    local y = sin.(q/2)
    local y_exact = k*sn.(t, k) # the exact solution

    plot(t, y,       label="numerical", lw=1)
    plot(t, y_exact, label="exact",     lw=1, ls="--")
    grid(ls=":")
    xlabel("t")
    ylabel("y = sin(q(t)/2)")
    legend()
    local error_str = @sprintf("%.3e", maximum(abs.(y - y_exact)))
    title("maximum(abs(numerical - exact)) = $error_str", fontsize=10)
end

# plot solution and energy
#
function plotsolenergy(H, integrator, Δt, sol::ODESolution)
    local integrator_str = replace("$integrator", r"^[^.]*\." => "")

    figure(figsize=(10,8))

    subplot2grid((21,20), ( 1, 0), rowspan=10, colspan=10)
    plotsol(sol)

    subplot2grid((21,20), ( 1,10), rowspan=10, colspan=10)
    plotsol2(sol)

    subplot2grid((21,20), (11, 0), rowspan=10, colspan=10)
    plotenergy(H, sol)

    suptitle("=====    $integrator_str,   Δt = $Δt    =====")
end

# Solve a single pendulum
#
function singlependulum(k, integrator, Δt; t0 = 0.0, t1 = 100.0)
    local H(p,q,params) = p[1]^2/2 - cos(q[1]) + 1
    local q0 = [0.0]
    local p0 = [2k]
    local prob = HamiltonianProblem(H, p0, q0, (t0, t1))

    local integrator_str = replace("$integrator", r"^[^.]*\." => "")
    @printf("%-25s", "$integrator_str:")
    sol = solve(prob, integrator, dt=Δt)
    @time local sol = solve(prob, integrator, dt=Δt)

    sleep(0.1)
    figure(figsize=(10,8))

    subplot2grid((21,20), ( 1, 0), rowspan=10, colspan=10)
    plotsol(sol)

    subplot2grid((21,20), ( 1,10), rowspan=10, colspan=10)
    plotsol2(sol)

    subplot2grid((21,20), (11, 0), rowspan=10, colspan=10)
    plotenergy(H, sol)

    subplot2grid((21,20), (11,10), rowspan=10, colspan=10)
    plotcomparison(k, sol)

    suptitle("=====    $integrator_str,   Δt = $Δt    =====")
end
```

```
Collecting package metadata (current_repodata.json): ...working... done
Solving environment: ...working... failed with initial frozen solve. Retryi
ng with flexible solve.
Solving environment: ...working... failed with repodata from current_repoda
ta.json, will retry with next repodata source.
Collecting package metadata (repodata.json): ...working... done
Solving environment: ...working... done

## Package Plan ##

  environment location: /cache/julia-buildkite-plugin/depots/5b300254-1738-
4989-ae0a-f4d2d937f953/conda/3

  added / updated specs:
    - matplotlib


The following packages will be downloaded:

    package                    |            build
    ---------------------------|-----------------
    alsa-lib-1.2.6.1           |       h7f98852_0         578 KB  conda-for
ge
    attr-2.5.1                 |       h166bdaf_1          69 KB  conda-for
ge
    brotli-1.0.9               |       h166bdaf_7          18 KB  conda-for
ge
    brotli-bin-1.0.9           |       h166bdaf_7          19 KB  conda-for
ge
    cycler-0.11.0              |     pyhd8ed1ab_0          10 KB  conda-for
ge
    dbus-1.13.6                |       h5008d03_3         604 KB  conda-for
ge
    expat-2.4.8                |       h27087fc_0         187 KB  conda-for
ge
    fftw-3.3.10                |nompi_ha7695d1_103         6.5 MB  conda-fo
rge
    font-ttf-dejavu-sans-mono-2.37|       hab24e00_0         388 KB  conda-
forge
    font-ttf-inconsolata-3.000 |       h77eed37_0          94 KB  conda-for
ge
    font-ttf-source-code-pro-2.038|       h77eed37_0         684 KB  conda-
forge
    font-ttf-ubuntu-0.83       |       hab24e00_0         1.9 MB  conda-for
ge
    fontconfig-2.14.0          |       h8e229c2_0         305 KB  conda-for
ge
    fonts-conda-ecosystem-1    |                0           4 KB  conda-for
ge
    fonts-conda-forge-1        |                0           4 KB  conda-for
ge
    fonttools-4.34.4           |   py39hb9d737c_0         1.6 MB  conda-for
ge
    freetype-2.10.4            |       hca18f0e_2         913 KB  conda-for
ge
    gettext-0.19.8.1           |    h73d1719_1008         3.6 MB  conda-for
ge
    glib-2.72.1                |       h6239696_0         443 KB  conda-for
ge
    glib-tools-2.72.1          |       h6239696_0         107 KB  conda-for
ge
    gst-plugins-base-1.20.3    |       hf6a322e_0         2.8 MB  conda-for
ge
    gstreamer-1.20.3           |       hd4edc92_0         2.0 MB  conda-for
ge
    icu-70.1                   |       h27087fc_0        13.5 MB  conda-for
ge
    jack-1.9.18                |    h8c3723f_1002         643 KB  conda-for
ge
    jpeg-9e                    |       h166bdaf_2         269 KB  conda-for
ge
    keyutils-1.6.1             |       h166bdaf_0         115 KB  conda-for
ge
    kiwisolver-1.4.4           |   py39hf939315_0          76 KB  conda-for
ge
    krb5-1.19.3                |       h3790be6_0         1.4 MB  conda-for
ge
    lcms2-2.12                 |       hddcbb42_0         443 KB  conda-for
ge
    lerc-4.0.0                 |       h27087fc_0         275 KB  conda-for
ge
    libbrotlicommon-1.0.9      |       h166bdaf_7          65 KB  conda-for
ge
    libbrotlidec-1.0.9         |       h166bdaf_7          33 KB  conda-for
ge
    libbrotlienc-1.0.9         |       h166bdaf_7         287 KB  conda-for
ge
    libcap-2.64                |       ha37c62d_0          96 KB  conda-for
ge
    libclang-14.0.6            |default_h2e3cab8_0         127 KB  conda-fo
rge
    libclang13-14.0.6          |default_h3a83d3e_0        10.6 MB  conda-fo
rge
    libcups-2.3.3              |       h3e49a29_2         4.5 MB  conda-for
ge
    libdb-6.2.32               |       h9c3ff4c_0        23.3 MB  conda-for
ge
    libdeflate-1.13            |       h166bdaf_0          79 KB  conda-for
ge
    libedit-3.1.20191231       |       he28a2e2_2         121 KB  conda-for
ge
    libevent-2.1.10            |       h9b69904_4         1.1 MB  conda-for
ge
    libflac-1.3.4              |       h27087fc_0         474 KB  conda-for
ge
    libglib-2.72.1             |       h2d90d5f_0         3.1 MB  conda-for
ge
    libiconv-1.16              |       h516909a_0         1.4 MB  conda-for
ge
    libllvm14-14.0.6           |       he0ac6c6_0        35.2 MB  conda-for
ge
    libogg-1.3.4               |       h7f98852_1         206 KB  conda-for
ge
    libopus-1.3.1              |       h7f98852_1         255 KB  conda-for
ge
    libpng-1.6.37              |       h753d276_4         371 KB  conda-for
ge
    libpq-14.5                 |       hd77ab85_0         3.0 MB  conda-for
ge
    libsndfile-1.0.31          |       h9c3ff4c_1         602 KB  conda-for
ge
    libtiff-4.4.0              |       h0e0dad5_3         642 KB  conda-for
ge
    libtool-2.4.6              |    h9c3ff4c_1008         511 KB  conda-for
ge
    libudev1-249               |       h166bdaf_4         109 KB  conda-for
ge
    libvorbis-1.3.7            |       h9c3ff4c_0         280 KB  conda-for
ge
    libwebp-base-1.2.4         |       h166bdaf_0         404 KB  conda-for
ge
    libxcb-1.13                |    h7f98852_1004         391 KB  conda-for
ge
    libxkbcommon-1.0.3         |       he3ba5ed_0         581 KB  conda-for
ge
    libxml2-2.9.14             |       h22db469_4         771 KB  conda-for
ge
    lz4-c-1.9.3                |       h9c3ff4c_1         179 KB  conda-for
ge
    matplotlib-3.5.2           |   py39hf3d152e_1           7 KB  conda-for
ge
    matplotlib-base-3.5.2      |   py39h700656a_1         7.4 MB  conda-for
ge
    munkres-1.1.4              |     pyh9f0ad1d_0          12 KB  conda-for
ge
    mysql-common-8.0.30        |       haf5c9bc_0         1.9 MB  conda-for
ge
    mysql-libs-8.0.30          |       h28c427c_0         1.9 MB  conda-for
ge
    nspr-4.32                  |       h9c3ff4c_1         233 KB  conda-for
ge
    nss-3.78                   |       h2350873_0         2.1 MB  conda-for
ge
    openjpeg-2.5.0             |       h7d73246_1         533 KB  conda-for
ge
    packaging-21.3             |     pyhd8ed1ab_0          36 KB  conda-for
ge
    pcre-8.45                  |       h9c3ff4c_0         253 KB  conda-for
ge
    pillow-9.2.0               |   py39hd5dbb17_2        44.9 MB  conda-for
ge
    ply-3.11                   |             py_1          44 KB  conda-for
ge
    portaudio-19.6.0           |       h57a0ea0_5         131 KB  conda-for
ge
    pthread-stubs-0.4          |    h36c2ea0_1001           5 KB  conda-for
ge
    pulseaudio-14.0            |       h7f54b18_8         1.7 MB  conda-for
ge
    pyparsing-3.0.9            |     pyhd8ed1ab_0          79 KB  conda-for
ge
    pyqt-5.15.7                |   py39h18e9c17_0         6.2 MB  conda-for
ge
    pyqt5-sip-12.11.0          |   py39h5a03fae_0          86 KB  conda-for
ge
    python-dateutil-2.8.2      |     pyhd8ed1ab_0         240 KB  conda-for
ge
    qt-main-5.15.4             |       ha5833f6_2        61.5 MB  conda-for
ge
    sip-6.6.2                  |   py39h5a03fae_0         495 KB  conda-for
ge
    toml-0.10.2                |     pyhd8ed1ab_0          18 KB  conda-for
ge
    tornado-6.2                |   py39hb9d737c_0         658 KB  conda-for
ge
    unicodedata2-14.0.0        |   py39hb9d737c_1         498 KB  conda-for
ge
    xcb-util-0.4.0             |       h166bdaf_0          20 KB  conda-for
ge
    xcb-util-image-0.4.0       |       h166bdaf_0          24 KB  conda-for
ge
    xcb-util-keysyms-0.4.0     |       h166bdaf_0          12 KB  conda-for
ge
    xcb-util-renderutil-0.3.9  |       h166bdaf_0          15 KB  conda-for
ge
    xcb-util-wm-0.4.1          |       h166bdaf_0          55 KB  conda-for
ge
    xorg-libxau-1.0.9          |       h7f98852_0          13 KB  conda-for
ge
    xorg-libxdmcp-1.1.3        |       h7f98852_0          19 KB  conda-for
ge
    zstd-1.5.2                 |       h8a70e8d_4         448 KB  conda-for
ge
    ------------------------------------------------------------
                                           Total:       259.5 MB

The following NEW packages will be INSTALLED:

  alsa-lib           conda-forge/linux-64::alsa-lib-1.2.6.1-h7f98852_0
  attr               conda-forge/linux-64::attr-2.5.1-h166bdaf_1
  brotli             conda-forge/linux-64::brotli-1.0.9-h166bdaf_7
  brotli-bin         conda-forge/linux-64::brotli-bin-1.0.9-h166bdaf_7
  cycler             conda-forge/noarch::cycler-0.11.0-pyhd8ed1ab_0
  dbus               conda-forge/linux-64::dbus-1.13.6-h5008d03_3
  expat              conda-forge/linux-64::expat-2.4.8-h27087fc_0
  fftw               conda-forge/linux-64::fftw-3.3.10-nompi_ha7695d1_103
  font-ttf-dejavu-s~ conda-forge/noarch::font-ttf-dejavu-sans-mono-2.37-hab
24e00_0
  font-ttf-inconsol~ conda-forge/noarch::font-ttf-inconsolata-3.000-h77eed3
7_0
  font-ttf-source-c~ conda-forge/noarch::font-ttf-source-code-pro-2.038-h77
eed37_0
  font-ttf-ubuntu    conda-forge/noarch::font-ttf-ubuntu-0.83-hab24e00_0
  fontconfig         conda-forge/linux-64::fontconfig-2.14.0-h8e229c2_0
  fonts-conda-ecosy~ conda-forge/noarch::fonts-conda-ecosystem-1-0
  fonts-conda-forge  conda-forge/noarch::fonts-conda-forge-1-0
  fonttools          conda-forge/linux-64::fonttools-4.34.4-py39hb9d737c_0
  freetype           conda-forge/linux-64::freetype-2.10.4-hca18f0e_2
  gettext            conda-forge/linux-64::gettext-0.19.8.1-h73d1719_1008
  glib               conda-forge/linux-64::glib-2.72.1-h6239696_0
  glib-tools         conda-forge/linux-64::glib-tools-2.72.1-h6239696_0
  gst-plugins-base   conda-forge/linux-64::gst-plugins-base-1.20.3-hf6a322e
_0
  gstreamer          conda-forge/linux-64::gstreamer-1.20.3-hd4edc92_0
  icu                conda-forge/linux-64::icu-70.1-h27087fc_0
  jack               conda-forge/linux-64::jack-1.9.18-h8c3723f_1002
  jpeg               conda-forge/linux-64::jpeg-9e-h166bdaf_2
  keyutils           conda-forge/linux-64::keyutils-1.6.1-h166bdaf_0
  kiwisolver         conda-forge/linux-64::kiwisolver-1.4.4-py39hf939315_0
  krb5               conda-forge/linux-64::krb5-1.19.3-h3790be6_0
  lcms2              conda-forge/linux-64::lcms2-2.12-hddcbb42_0
  lerc               conda-forge/linux-64::lerc-4.0.0-h27087fc_0
  libbrotlicommon    conda-forge/linux-64::libbrotlicommon-1.0.9-h166bdaf_7
  libbrotlidec       conda-forge/linux-64::libbrotlidec-1.0.9-h166bdaf_7
  libbrotlienc       conda-forge/linux-64::libbrotlienc-1.0.9-h166bdaf_7
  libcap             conda-forge/linux-64::libcap-2.64-ha37c62d_0
  libclang           conda-forge/linux-64::libclang-14.0.6-default_h2e3cab8
_0
  libclang13         conda-forge/linux-64::libclang13-14.0.6-default_h3a83d
3e_0
  libcups            conda-forge/linux-64::libcups-2.3.3-h3e49a29_2
  libdb              conda-forge/linux-64::libdb-6.2.32-h9c3ff4c_0
  libdeflate         conda-forge/linux-64::libdeflate-1.13-h166bdaf_0
  libedit            conda-forge/linux-64::libedit-3.1.20191231-he28a2e2_2
  libevent           conda-forge/linux-64::libevent-2.1.10-h9b69904_4
  libflac            conda-forge/linux-64::libflac-1.3.4-h27087fc_0
  libglib            conda-forge/linux-64::libglib-2.72.1-h2d90d5f_0
  libiconv           conda-forge/linux-64::libiconv-1.16-h516909a_0
  libllvm14          conda-forge/linux-64::libllvm14-14.0.6-he0ac6c6_0
  libogg             conda-forge/linux-64::libogg-1.3.4-h7f98852_1
  libopus            conda-forge/linux-64::libopus-1.3.1-h7f98852_1
  libpng             conda-forge/linux-64::libpng-1.6.37-h753d276_4
  libpq              conda-forge/linux-64::libpq-14.5-hd77ab85_0
  libsndfile         conda-forge/linux-64::libsndfile-1.0.31-h9c3ff4c_1
  libtiff            conda-forge/linux-64::libtiff-4.4.0-h0e0dad5_3
  libtool            conda-forge/linux-64::libtool-2.4.6-h9c3ff4c_1008
  libudev1           conda-forge/linux-64::libudev1-249-h166bdaf_4
  libvorbis          conda-forge/linux-64::libvorbis-1.3.7-h9c3ff4c_0
  libwebp-base       conda-forge/linux-64::libwebp-base-1.2.4-h166bdaf_0
  libxcb             conda-forge/linux-64::libxcb-1.13-h7f98852_1004
  libxkbcommon       conda-forge/linux-64::libxkbcommon-1.0.3-he3ba5ed_0
  libxml2            conda-forge/linux-64::libxml2-2.9.14-h22db469_4
  lz4-c              conda-forge/linux-64::lz4-c-1.9.3-h9c3ff4c_1
  matplotlib         conda-forge/linux-64::matplotlib-3.5.2-py39hf3d152e_1
  matplotlib-base    conda-forge/linux-64::matplotlib-base-3.5.2-py39h70065
6a_1
  munkres            conda-forge/noarch::munkres-1.1.4-pyh9f0ad1d_0
  mysql-common       conda-forge/linux-64::mysql-common-8.0.30-haf5c9bc_0
  mysql-libs         conda-forge/linux-64::mysql-libs-8.0.30-h28c427c_0
  nspr               conda-forge/linux-64::nspr-4.32-h9c3ff4c_1
  nss                conda-forge/linux-64::nss-3.78-h2350873_0
  openjpeg           conda-forge/linux-64::openjpeg-2.5.0-h7d73246_1
  packaging          conda-forge/noarch::packaging-21.3-pyhd8ed1ab_0
  pcre               conda-forge/linux-64::pcre-8.45-h9c3ff4c_0
  pillow             conda-forge/linux-64::pillow-9.2.0-py39hd5dbb17_2
  ply                conda-forge/noarch::ply-3.11-py_1
  portaudio          conda-forge/linux-64::portaudio-19.6.0-h57a0ea0_5
  pthread-stubs      conda-forge/linux-64::pthread-stubs-0.4-h36c2ea0_1001
  pulseaudio         conda-forge/linux-64::pulseaudio-14.0-h7f54b18_8
  pyparsing          conda-forge/noarch::pyparsing-3.0.9-pyhd8ed1ab_0
  pyqt               conda-forge/linux-64::pyqt-5.15.7-py39h18e9c17_0
  pyqt5-sip          conda-forge/linux-64::pyqt5-sip-12.11.0-py39h5a03fae_0
  python-dateutil    conda-forge/noarch::python-dateutil-2.8.2-pyhd8ed1ab_0
  qt-main            conda-forge/linux-64::qt-main-5.15.4-ha5833f6_2
  sip                conda-forge/linux-64::sip-6.6.2-py39h5a03fae_0
  toml               conda-forge/noarch::toml-0.10.2-pyhd8ed1ab_0
  tornado            conda-forge/linux-64::tornado-6.2-py39hb9d737c_0
  unicodedata2       conda-forge/linux-64::unicodedata2-14.0.0-py39hb9d737c
_1
  xcb-util           conda-forge/linux-64::xcb-util-0.4.0-h166bdaf_0
  xcb-util-image     conda-forge/linux-64::xcb-util-image-0.4.0-h166bdaf_0
  xcb-util-keysyms   conda-forge/linux-64::xcb-util-keysyms-0.4.0-h166bdaf_
0
  xcb-util-renderut~ conda-forge/linux-64::xcb-util-renderutil-0.3.9-h166bd
af_0
  xcb-util-wm        conda-forge/linux-64::xcb-util-wm-0.4.1-h166bdaf_0
  xorg-libxau        conda-forge/linux-64::xorg-libxau-1.0.9-h7f98852_0
  xorg-libxdmcp      conda-forge/linux-64::xorg-libxdmcp-1.1.3-h7f98852_0
  zstd               conda-forge/linux-64::zstd-1.5.2-h8a70e8d_4


Preparing transaction: ...working... done
Verifying transaction: ...working... done
Executing transaction: ...working... done
singlependulum (generic function with 1 method)
```





## Tests

```julia
# Single pendulum

k = rand()
integrator = VelocityVerlet()
Δt = 0.1
singlependulum(k, integrator, Δt, t0=-20.0, t1=20.0)
```

```
VelocityVerlet():          0.000257 seconds (2.90 k allocations: 205.859 Ki
B)
PyObject Text(0.5, 0.98, '=====    VelocityVerlet(),   Δt = 0.1    =====')
```



```julia
# Two single pendulums

H(q,p,param) = sum(p.^2/2 .- cos.(q) .+ 1)
q0 = pi*rand(2)
p0 = zeros(2)
t0, t1 = -20.0, 20.0
prob = HamiltonianProblem(H, q0, p0, (t0, t1))

integrator = McAte4()
Δt = 0.1
sol = solve(prob, integrator, dt=Δt)
@time sol = solve(prob, integrator, dt=Δt)

sleep(0.1)
plotsolenergy(H, integrator, Δt, sol)
```

```
0.000821 seconds (13.70 k allocations: 1.295 MiB)
PyObject Text(0.5, 0.98, '=====    McAte4(),   Δt = 0.1    =====')
```





## Comparison of symplectic Integrators

```julia
SymplecticIntegrators = [
    SymplecticEuler(),
    VelocityVerlet(),
    VerletLeapfrog(),
    PseudoVerletLeapfrog(),
    McAte2(),
    Ruth3(),
    McAte3(),
    CandyRoz4(),
    McAte4(),
    CalvoSanz4(),
    McAte42(),
    McAte5(),
    Yoshida6(),
    KahanLi6(),
    McAte8(),
    KahanLi8(),
    SofSpa10(),
]

k = 0.999
Δt = 0.1
for integrator in SymplecticIntegrators
    singlependulum(k, integrator, Δt)
end
```

```
SymplecticEuler():         0.000496 seconds (7.09 k allocations: 505.797 Ki
B)
VelocityVerlet():          0.000419 seconds (7.10 k allocations: 505.859 Ki
B)
VerletLeapfrog():          0.000582 seconds (7.09 k allocations: 505.984 Ki
B)
PseudoVerletLeapfrog():    0.000633 seconds (7.09 k allocations: 505.984 Ki
B)
McAte2():                  0.000602 seconds (7.09 k allocations: 505.984 Ki
B)
Ruth3():                   0.000660 seconds (7.11 k allocations: 506.406 Ki
B)
McAte3():                  0.000626 seconds (7.09 k allocations: 506.094 Ki
B)
CandyRoz4():               0.000677 seconds (7.10 k allocations: 506.438 Ki
B)
McAte4():                  0.000704 seconds (7.09 k allocations: 506.250 Ki
B)
CalvoSanz4():              0.000709 seconds (7.09 k allocations: 506.391 Ki
B)
McAte42():                 0.000721 seconds (7.09 k allocations: 506.391 Ki
B)
McAte5():                  0.000766 seconds (7.09 k allocations: 506.609 Ki
B)
Yoshida6():                0.000900 seconds (7.09 k allocations: 506.672 Ki
B)
KahanLi6():                0.000996 seconds (7.09 k allocations: 507.000 Ki
B)
McAte8():                  0.001281 seconds (7.09 k allocations: 507.797 Ki
B)
KahanLi8():                0.001375 seconds (7.09 k allocations: 508.047 Ki
B)
SofSpa10():                0.002165 seconds (7.09 k allocations: 510.297 Ki
B)
```



```julia
k = 0.999
Δt = 0.01
for integrator in SymplecticIntegrators[1:4]
    singlependulum(k, integrator, Δt)
end
```

```
SymplecticEuler():         0.004166 seconds (70.09 k allocations: 4.888 MiB
)
VelocityVerlet():          0.004395 seconds (70.10 k allocations: 4.889 MiB
)
VerletLeapfrog():          0.005147 seconds (70.09 k allocations: 4.889 MiB
)
PseudoVerletLeapfrog():    0.005602 seconds (70.09 k allocations: 4.889 MiB
)
```



```julia
k = 0.999
Δt = 0.001
singlependulum(k, SymplecticEuler(), Δt)
```

```
SymplecticEuler():         0.051536 seconds (700.09 k allocations: 48.834 M
iB)
PyObject Text(0.5, 0.98, '=====    SymplecticEuler(),   Δt = 0.001    =====
')
```



```julia
k = 0.999
Δt = 0.0001
singlependulum(k, SymplecticEuler(), Δt)
```

```
SymplecticEuler():         0.518554 seconds (7.00 M allocations: 488.287 Mi
B)
PyObject Text(0.5, 0.98, '=====    SymplecticEuler(),   Δt = 0.0001    ====
=')
```




## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/DynamicalODE","single_pendulums.jmd")
```

Computer Information:

```
Julia Version 1.7.3
Commit 742b9abb4d (2022-05-06 12:58 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: AMD EPYC 7502 32-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-12.0.1 (ORCJIT, znver2)
Environment:
  JULIA_CPU_THREADS = 128
  BUILDKITE_PLUGIN_JULIA_CACHE_DIR = /cache/julia-buildkite-plugin
  JULIA_DEPOT_PATH = /cache/julia-buildkite-plugin/depots/5b300254-1738-4989-ae0a-f4d2d937f953

```

Package Information:

```
      Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Project.toml`
  [459566f4] DiffEqCallbacks v2.23.1
  [055956cb] DiffEqPhysics v3.9.0
  [b305315f] Elliptic v1.0.1
  [1dea7af3] OrdinaryDiffEq v6.19.1
  [65888b18] ParameterizedFunctions v5.13.2
  [91a5bcdd] Plots v1.31.4
  [d330b81b] PyPlot v2.10.0
  [31c91b34] SciMLBenchmarks v0.1.0
  [90137ffa] StaticArrays v1.5.2
  [92b13dbe] TaylorIntegration v0.8.11
  [37e2e46d] LinearAlgebra
  [de0858da] Printf
  [10745b16] Statistics
```

And the full manifest:

```
      Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Manifest.toml`
  [c3fe647b] AbstractAlgebra v0.27.0
  [1520ce14] AbstractTrees v0.4.2
  [79e6a3ab] Adapt v3.3.3
  [dce04be8] ArgCheck v2.3.0
  [ec485272] ArnoldiMethod v0.2.0
  [4fba245c] ArrayInterface v6.0.21
  [30b0a656] ArrayInterfaceCore v0.1.15
  [6ba088a2] ArrayInterfaceGPUArrays v0.2.1
  [015c0d05] ArrayInterfaceOffsetArrays v0.1.6
  [b0d46f97] ArrayInterfaceStaticArrays v0.1.4
  [dd5226c6] ArrayInterfaceStaticArraysCore v0.1.0
  [15f4f7f2] AutoHashEquals v0.2.0
  [198e06fe] BangBang v0.3.36
  [9718e550] Baselet v0.1.1
  [e2ed5e7c] Bijections v0.1.4
  [62783981] BitTwiddlingConvenienceFunctions v0.1.4
  [2a0fbf3d] CPUSummary v0.1.25
  [00ebfdb7] CSTParser v3.3.6
  [49dc2e85] Calculus v0.5.1
  [d360d2e6] ChainRulesCore v1.15.3
  [9e997f8a] ChangesOfVariables v0.1.4
  [fb6a15b2] CloseOpenIntervals v0.1.10
  [944b1d66] CodecZlib v0.7.0
  [35d6a980] ColorSchemes v3.19.0
  [3da002f7] ColorTypes v0.11.4
  [c3611d14] ColorVectorSpace v0.9.9
  [5ae59095] Colors v0.12.8
  [861a8166] Combinatorics v1.0.2
  [a80b9123] CommonMark v0.8.6
  [38540f10] CommonSolve v0.2.1
  [bbf7d656] CommonSubexpressions v0.3.0
  [34da2185] Compat v3.45.0
  [b152e2b5] CompositeTypes v0.1.2
  [a33af91c] CompositionsBase v0.1.1
  [8f4d0f93] Conda v1.7.0
  [187b0558] ConstructionBase v1.4.0
  [d38c429a] Contour v0.6.2
  [adafc99b] CpuId v0.3.1
  [a8cc5b0e] Crayons v4.1.1
  [9a962f9c] DataAPI v1.10.0
  [864edb3b] DataStructures v0.18.13
  [e2d170a0] DataValueInterfaces v1.0.0
  [244e2a9f] DefineSingletons v0.1.2
  [b429d917] DensityInterface v0.4.0
  [2b5f629d] DiffEqBase v6.94.4
  [459566f4] DiffEqCallbacks v2.23.1
  [055956cb] DiffEqPhysics v3.9.0
  [163ba53b] DiffResults v1.0.3
  [b552c78f] DiffRules v1.11.0
  [b4f34e82] Distances v0.10.7
  [31c24e10] Distributions v0.25.66
  [ffbed154] DocStringExtensions v0.8.6
  [5b8099bc] DomainSets v0.5.11
  [fa6b7ba4] DualNumbers v0.6.8
  [7c1d4256] DynamicPolynomials v0.4.5
  [b305315f] Elliptic v1.0.1
  [6912e4f1] Espresso v0.6.1
  [d4d017d3] ExponentialUtilities v1.18.0
  [e2ba6199] ExprTools v0.1.8
  [c87230d0] FFMPEG v0.4.1
  [7034ab61] FastBroadcast v0.2.1
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v1.1.0
  [1a297f60] FillArrays v0.13.2
  [6a86dc24] FiniteDiff v2.13.1
  [53c48c17] FixedPointNumbers v0.8.4
  [59287772] Formatting v0.4.2
  [f6369f11] ForwardDiff v0.10.30
  [069b7b12] FunctionWrappers v1.1.2
  [46192b85] GPUArraysCore v0.1.1
  [28b8d3ca] GR v0.66.0
  [c145ed77] GenericSchur v0.5.3
  [5c1252a2] GeometryBasics v0.4.2
  [d7ba0133] Git v1.2.1
  [86223c79] Graphs v1.7.1
  [42e2da0e] Grisu v1.0.2
  [0b43b601] Groebner v0.2.8
  [d5909c97] GroupsCore v0.4.0
  [cd3eb016] HTTP v1.2.0
  [eafb193a] Highlights v0.4.5
  [3e5b6fbb] HostCPUFeatures v0.1.8
  [34004b35] HypergeometricFunctions v0.3.11
  [7073ff75] IJulia v1.23.3
  [615f187c] IfElse v0.1.1
  [d25df0c9] Inflate v0.1.2
  [83e8ac13] IniFile v0.5.1
  [22cec73e] InitialValues v0.3.1
  [18e54dd8] IntegerMathUtils v0.1.0
  [8197267c] IntervalSets v0.7.1
  [3587e190] InverseFunctions v0.1.7
  [92d709cd] IrrationalConstants v0.1.1
  [c8e1da08] IterTools v1.4.0
  [42fd0dbc] IterativeSolvers v0.9.2
  [82899510] IteratorInterfaceExtensions v1.0.0
  [692b3bcd] JLLWrappers v1.4.1
  [682c06a0] JSON v0.21.3
  [98e50ef6] JuliaFormatter v1.0.7
  [ccbc3e58] JumpProcesses v9.0.1
  [ef3ab10e] KLU v0.3.0
  [ba0b0d4f] Krylov v0.8.2
  [0b1a1467] KrylovKit v0.5.4
  [b964fa9f] LaTeXStrings v1.3.0
  [2ee39098] LabelledArrays v1.11.1
  [23fbe1c1] Latexify v0.15.16
  [10f19ff3] LayoutPointers v0.1.10
  [d3d80556] LineSearches v7.1.1
  [7ed4a6bd] LinearSolve v1.23.0
  [2ab3a3ac] LogExpFunctions v0.3.16
  [e6f89c97] LoggingExtras v0.4.9
  [bdcacae8] LoopVectorization v0.12.120
  [1914dd2f] MacroTools v0.5.9
  [d125e4d3] ManualMemory v0.1.8
  [739be429] MbedTLS v1.1.1
  [442fdcdd] Measures v0.3.1
  [e9d8d322] Metatheory v1.3.4
  [128add7d] MicroCollections v0.1.2
  [e1d29d7a] Missings v1.0.2
  [961ee093] ModelingToolkit v8.18.0
  [46d2c3a1] MuladdMacro v0.2.2
  [102ac46a] MultivariatePolynomials v0.4.6
  [ffc61752] Mustache v1.0.14
  [d8a4904e] MutableArithmetics v1.0.4
  [d41bc354] NLSolversBase v7.8.2
  [2774e3e8] NLsolve v4.5.1
  [77ba4419] NaNMath v0.3.7
  [8913a72c] NonlinearSolve v0.3.21
  [6fe1bfb0] OffsetArrays v1.12.7
  [bac558e1] OrderedCollections v1.4.1
  [1dea7af3] OrdinaryDiffEq v6.19.1
  [90014a1f] PDMats v0.11.16
  [65888b18] ParameterizedFunctions v5.13.2
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.3.2
  [ccf2f8ad] PlotThemes v3.0.0
  [995b91a9] PlotUtils v1.3.0
  [91a5bcdd] Plots v1.31.4
  [e409e4f3] PoissonRandom v0.4.1
  [f517fe37] Polyester v0.6.14
  [1d0040c9] PolyesterWeave v0.1.7
  [d236fae5] PreallocationTools v0.4.0
  [21216c6a] Preferences v1.3.0
  [27ebfcd6] Primes v0.5.3
  [438e738f] PyCall v1.93.1
  [d330b81b] PyPlot v2.10.0
  [1fd47b50] QuadGK v2.4.2
  [fb686558] RandomExtensions v0.4.3
  [e6cf234a] RandomNumbers v1.5.3
  [3cdcf5f2] RecipesBase v1.2.1
  [01d81517] RecipesPipeline v0.6.2
  [731186ca] RecursiveArrayTools v2.31.2
  [f2c3362d] RecursiveFactorization v0.2.11
  [189a3867] Reexport v1.2.2
  [42d2dcc6] Referenceables v0.1.2
  [05181044] RelocatableFolders v0.3.0
  [ae029012] Requires v1.3.0
  [79098fc4] Rmath v0.7.0
  [7e49a35a] RuntimeGeneratedFunctions v0.5.3
  [3cdde19b] SIMDDualNumbers v0.1.1
  [94e857df] SIMDTypes v0.1.0
  [476501e8] SLEEFPirates v0.6.33
  [0bca4576] SciMLBase v1.44.1
  [31c91b34] SciMLBenchmarks v0.1.0
  [6c6a2e73] Scratch v1.1.1
  [efcf1570] Setfield v0.8.2
  [992d4aef] Showoff v1.0.3
  [777ac1f9] SimpleBufferStream v1.1.0
  [699a6c99] SimpleTraits v0.9.4
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.0.1
  [47a9eef4] SparseDiffTools v1.24.0
  [276daf66] SpecialFunctions v2.1.7
  [171d559e] SplittablesBase v0.1.14
  [aedffcd0] Static v0.7.6
  [90137ffa] StaticArrays v1.5.2
  [1e83bf80] StaticArraysCore v1.0.1
  [82ae8749] StatsAPI v1.4.0
  [2913bbd2] StatsBase v0.33.20
  [4c63d2b9] StatsFuns v1.0.1
  [7792a7ef] StrideArraysCore v0.3.15
  [69024149] StringEncodings v0.3.5
  [09ab397b] StructArrays v0.6.11
  [d1185830] SymbolicUtils v0.19.11
  [0c5d862f] Symbolics v4.10.0
  [3783bdb8] TableTraits v1.0.1
  [bd369af6] Tables v1.7.0
  [92b13dbe] TaylorIntegration v0.8.11
  [6aa5eb33] TaylorSeries v0.12.1
  [62fd8b95] TensorCore v0.1.1
  [8ea1fca8] TermInterface v0.2.3
  [8290d209] ThreadingUtilities v0.5.0
  [ac1d9e8a] ThreadsX v0.1.10
  [a759f4b9] TimerOutputs v0.5.20
  [0796e94c] Tokenize v0.5.24
  [3bb67fe8] TranscodingStreams v0.9.6
  [28d57a85] Transducers v0.4.73
  [a2a6695c] TreeViews v0.3.0
  [d5829a12] TriangularSolve v0.1.12
  [5c2747f8] URIs v1.4.0
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
  [1986cc42] Unitful v1.11.0
  [41fe7b60] Unzip v0.1.2
  [3d5dd08c] VectorizationBase v0.21.43
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.9
  [ddb6d928] YAML v0.4.7
  [c2297ded] ZMQ v1.2.1
  [700de1a5] ZygoteRules v0.2.2
  [6e34b625] Bzip2_jll v1.0.8+0
  [83423d85] Cairo_jll v1.16.1+1
  [5ae413db] EarCut_jll v2.2.3+0
  [2e619515] Expat_jll v2.4.8+0
  [b22a6f82] FFMPEG_jll v4.4.2+0
  [a3f928ae] Fontconfig_jll v2.13.93+0
  [d7e528f0] FreeType2_jll v2.10.4+0
  [559328eb] FriBidi_jll v1.0.10+0
  [0656b61e] GLFW_jll v3.3.6+0
  [d2c73de3] GR_jll v0.66.0+0
  [78b55507] Gettext_jll v0.21.0+0
  [f8c6e375] Git_jll v2.34.1+0
  [7746bdde] Glib_jll v2.68.3+2
  [3b182d85] Graphite2_jll v1.3.14+0
  [2e76f6c2] HarfBuzz_jll v2.8.1+1
  [aacddb02] JpegTurbo_jll v2.1.2+0
  [c1c5ebd0] LAME_jll v3.100.1+0
  [88015f11] LERC_jll v3.0.0+1
  [dd4b983a] LZO_jll v2.10.1+0
  [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.7+0
  [7e76a0d4] Libglvnd_jll v1.3.0+3
  [7add5ba3] Libgpg_error_jll v1.42.0+0
  [94ce4f54] Libiconv_jll v1.16.1+1
  [4b2f31a3] Libmount_jll v2.35.0+0
  [89763e89] Libtiff_jll v4.4.0+0
  [38a345b3] Libuuid_jll v2.36.0+0
  [e7412a2a] Ogg_jll v1.3.5+1
  [458c3c95] OpenSSL_jll v1.1.17+0
  [efe28fd5] OpenSpecFun_jll v0.5.5+0
  [91d4177d] Opus_jll v1.3.2+0
  [2f80f16e] PCRE_jll v8.44.0+0
  [30392449] Pixman_jll v0.40.1+0
  [ea2cea3b] Qt5Base_jll v5.15.3+1
  [f50d1b31] Rmath_jll v0.3.0+0
  [a2964d1f] Wayland_jll v1.19.0+0
  [2381bf8a] Wayland_protocols_jll v1.25.0+0
  [02c8fc9c] XML2_jll v2.9.14+0
  [aed1982a] XSLT_jll v1.1.34+0
  [4f6342f7] Xorg_libX11_jll v1.6.9+4
  [0c0b7dd1] Xorg_libXau_jll v1.0.9+4
  [935fb764] Xorg_libXcursor_jll v1.2.0+4
  [a3789734] Xorg_libXdmcp_jll v1.1.3+4
  [1082639a] Xorg_libXext_jll v1.3.4+4
  [d091e8ba] Xorg_libXfixes_jll v5.0.3+4
  [a51aa0fd] Xorg_libXi_jll v1.7.10+4
  [d1454406] Xorg_libXinerama_jll v1.1.4+4
  [ec84b674] Xorg_libXrandr_jll v1.5.2+4
  [ea2f1a96] Xorg_libXrender_jll v0.9.10+4
  [14d82f49] Xorg_libpthread_stubs_jll v0.1.0+3
  [c7cfdc94] Xorg_libxcb_jll v1.13.0+3
  [cc61e674] Xorg_libxkbfile_jll v1.1.0+4
  [12413925] Xorg_xcb_util_image_jll v0.4.0+1
  [2def613f] Xorg_xcb_util_jll v0.4.0+1
  [975044d2] Xorg_xcb_util_keysyms_jll v0.4.0+1
  [0d47668e] Xorg_xcb_util_renderutil_jll v0.3.9+1
  [c22f9ab0] Xorg_xcb_util_wm_jll v0.4.1+1
  [35661453] Xorg_xkbcomp_jll v1.4.2+4
  [33bec58e] Xorg_xkeyboard_config_jll v2.27.0+4
  [c5fb5394] Xorg_xtrans_jll v1.4.0+3
  [8f1865be] ZeroMQ_jll v4.3.4+0
  [3161d3a3] Zstd_jll v1.5.2+0
  [a4ae2306] libaom_jll v3.4.0+0
  [0ac62f75] libass_jll v0.15.1+0
  [f638f0a6] libfdk_aac_jll v2.0.2+0
  [b53b4c65] libpng_jll v1.6.38+0
  [a9144af2] libsodium_jll v1.0.20+0
  [f27f6e37] libvorbis_jll v1.3.7+1
  [1270edf5] x264_jll v2021.5.5+0
  [dfaa095f] x265_jll v3.5.0+0
  [d8fb68d0] xkbcommon_jll v0.9.1+5
  [0dad84c5] ArgTools v1.1.1
  [56f22d72] Artifacts
  [2a0f44e3] Base64
  [ade2ca70] Dates
  [8bb1440f] DelimitedFiles
  [8ba89e20] Distributed
  [f43a241f] Downloads v1.6.0
  [7b1f6079] FileWatching
  [9fa8497b] Future
  [b77e0a4c] InteractiveUtils
  [b27032c2] LibCURL v0.6.3
  [76f85450] LibGit2
  [8f399da3] Libdl
  [37e2e46d] LinearAlgebra
  [56ddb016] Logging
  [d6f4376e] Markdown
  [a63ad114] Mmap
  [ca575930] NetworkOptions v1.2.0
  [44cfe95a] Pkg v1.8.0
  [de0858da] Printf
  [3fa0cd96] REPL
  [9a3f8284] Random
  [ea8e919c] SHA v0.7.0
  [9e88b42a] Serialization
  [1a1011a3] SharedArrays
  [6462fe0b] Sockets
  [2f01184e] SparseArrays
  [10745b16] Statistics
  [4607b0f0] SuiteSparse
  [fa267f1f] TOML v1.0.0
  [a4e569a6] Tar v1.10.0
  [8dfed614] Test
  [cf7118a7] UUIDs
  [4ec0a83e] Unicode
  [e66e0078] CompilerSupportLibraries_jll v0.5.2+0
  [deac9b47] LibCURL_jll v7.81.0+0
  [29816b5a] LibSSH2_jll v1.10.2+0
  [c8ffd9c3] MbedTLS_jll v2.28.0+0
  [14a3606d] MozillaCACerts_jll v2022.2.1
  [4536629a] OpenBLAS_jll v0.3.20+0
  [05823500] OpenLibm_jll v0.8.1+0
  [efcefdf7] PCRE2_jll v10.40.0+0
  [bea87d4a] SuiteSparse_jll v5.10.1+0
  [83775a58] Zlib_jll v1.2.12+3
  [8e850b90] libblastrampoline_jll v5.1.0+0
  [8e850ede] nghttp2_jll v1.41.0+1
  [3f19e933] p7zip_jll v17.4.0+0
```
