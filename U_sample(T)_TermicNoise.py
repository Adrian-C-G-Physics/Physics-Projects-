import numpy as np
import matplotlib.pyplot as plt

# ==============================
# Constantes físicas
# ==============================
kB = 1.380649e-23     # Boltzmann [J/K]
e = 1.602e-19         # Carga elemental [C]

# ==============================
# Parámetro del sistema (ruido)
# ==============================
C_noise = 3e22    # Parámetro C

# ==============================
# Parámetros del material (Ge)
# ==============================
Eg = 0.70             # Band gap [eV]
sigma0 = 1e5          # Prefactor conductividad [S/m]

# ==============================
# Geometría de la muestra
# ==============================
l = 0.02              # m
A = 1.1e-5            # m^2
d = 1e-3              # m

# ==============================
# Parámetros experimentales
# ==============================
I = 30e-3             # A
B = 0.30              # T (no se grafica UH)

# ==============================
# Temperaturas
# ==============================
T = np.linspace(300, 420, 150)  # K

# ==============================
# Conductividad (modelo ideal)
# ==============================
kB_eV = 8.617e-5      # Boltzmann [eV/K]
sigma = sigma0 * np.exp(-Eg / (2 * kB_eV * T))

# Tensión longitudinal ideal
R = l / (sigma * A)
Up_ideal = I * R

# ==============================
# (Opcional) Hall: se calcula pero NO se grafica
# ==============================
n0 = 1e21
nT = n0 * np.exp(-Eg / (2 * kB_eV * T))
RH = 1 / (e * nT)
UH_ideal = RH * I * B / d

# ==============================
# Ruido térmico gaussiano
# ==============================
sigma_noise = np.sqrt(4 * kB * T * C_noise)
noise_Up = np.random.normal(0, sigma_noise, size=T.size)

Up = Up_ideal + noise_Up

# ==============================
# GRÁFICA: U_p vs T (única que se muestra)
# ==============================
plt.figure()
plt.plot(T, Up_ideal, label="Ideal", linewidth=2)
plt.scatter(T, Up, s=12, alpha=0.6, label="Con ruido térmico")
plt.xlabel("Temperatura [K]")
plt.ylabel("Tensión longitudinal U_p [V]")
plt.title("Tensión de la muestra vs Temperatura")
plt.legend()
plt.grid()

# ==============================
# GRÁFICA EXTRA: ln(sigma) vs 1/T
# ==============================
invT = 1 / T                 # [1/K]
ln_sigma = np.log(sigma)     # ln(S/m)

plt.figure()
plt.plot(invT, ln_sigma, linewidth=2)
plt.xlabel(r"$1/T\ \mathrm{[K^{-1}]}$")
plt.ylabel(r"$\ln(\sigma)\ \mathrm{[S/m]}$")
plt.title(r" $\ln(\sigma)$ vs $1/T$")
plt.grid()


plt.show()