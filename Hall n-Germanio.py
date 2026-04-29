import numpy as np
import matplotlib.pyplot as plt


# ==============================
# Parámetros físicos (Ge tipo n)
# ==============================
RH_real_n = 4.8e-4      # Constante Hall (m^3/C)
d = 1.0e-3             # Espesor de la muestra (m) 1 mm

# ==============================
# 1) U_H vs Corriente (B constante)
# ==============================
B_const = 0.20         # Tesla
I = np.arange(-30e-3, 31e-3, 5e-3)  # Corriente en amperios

UH_I_N = RH_real_n * I * B_const / d

# Ruido experimental (4%)
UH_I_N += np.random.normal(0, 0.04 * np.max(np.abs(UH_I_N)), UH_I_N.size)

# Ajuste lineal
coef_I_N = np.polyfit(I, UH_I_N, 1)
UH_I_fit_N = np.polyval(coef_I_N, I)

# ==============================
# 2) U_H vs Campo magnético (I constante)
# ==============================
I_const = 30e-3        # 30 mA
B = np.linspace(0, 0.30, 13)

UH_B_N = RH_real_n * I_const * B / d
UH_B_N += np.random.normal(0, 0.04 * np.max(np.abs(UH_B_N)), UH_B_N.size)

# Ajuste lineal
coef_B_N = np.polyfit(B, UH_B_N, 1)
UH_B_fit_N = np.polyval(coef_B_N, B)

# ==============================
# Gráficas
# ==============================
plt.figure()
plt.plot(I * 1e3, UH_I_N * 1e3, 'o', label='Datos simulados')
plt.plot(I * 1e3, UH_I_fit_N * 1e3, '-', label='Ajuste lineal')
plt.xlabel('Corriente I (mA)')
plt.ylabel('Tensión Hall U_H (mV)')
plt.title('n-Germanio: U_H vs I (B = 0.2 T)')
plt.legend()
plt.grid()
plt.show()

plt.figure()
plt.plot(B, UH_B_N * 1e3, 'o', label='Datos simulados')
plt.plot(B, UH_B_fit_N * 1e3, '-', label='Ajuste lineal')
plt.xlabel('Campo magnético B (T)')
plt.ylabel('Tensión Hall U_H (mV)')
plt.title('n-Germanio: U_H vs B (I = 30 mA)')
plt.legend()
plt.grid()
plt.show()

# ==============================
# Resultados numéricos
# ==============================
print('--- Resultados del ajuste ---')
print(f'Pendiente U_H vs I  = {coef_I_N[0]:.3e} V/A')
print(f'Pendiente U_H vs B  = {coef_B_N[0]:.3e} V/T')

# Cálculo de R_H a partir del ajuste U_H vs B
RH_calc = coef_B_N[0] * d / I_const
print(f'Constante Hall R_H = {RH_calc:.3e} m^3/C')

