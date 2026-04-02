import tkinter as tk
from tkinter import messagebox
import math

# Constantes físicas
h = 6.62607015e-34       # Constante de Planck (J·s)
c = 2.99792458e8         # Velocidad de la luz (m/s)
eV = 1.602176634e-19     # Joule por eV

def calcular_transicion():
    try:
        m = int(entry_m.get())
        n = int(entry_n.get())

        if m <= n or m <= 0 or n <= 0:
            raise ValueError

    except ValueError:
        messagebox.showerror("Error", "Introduce valores enteros positivos con m > n.")
        return

    # Energías en eV
    E_m = -13.6 / (m**2)
    E_n = -13.6 / (n**2)
    delta_E = E_m - E_n  # eV (positivo)

    # Frecuencia y longitud de onda
    freq = (delta_E * eV) / h
    wavelength_m = c / freq
    wavelength_nm = wavelength_m * 1e9

    # Clasificación de serie
    if n == 1:
        serie = "Lyman"
    elif n == 2:
        serie = "Balmer"
    elif n == 3:
        serie = "Paschen"
    elif n == 4:
        serie = "Brackett"
    elif n == 5:
        serie = "Pfund"
    else:
        serie = "Humphreys o superior"

    # Región espectral
    if wavelength_nm < 380:
        region = "Ultravioleta (UV)"
    elif 380 <= wavelength_nm <= 750:
        region = "Visible"
    else:
        region = "Infrarrojo (IR)"

    # Mostrar resultados
    label_result.config(
        text=f"λ = {wavelength_nm:.2f} nm\n"
             f"ν = {freq:.3e} Hz\n"
             f"ΔE = {delta_E:.3f} eV\n"
             f"Serie: {serie}\n"
             f"Región: {region}"
    )

    # Color aproximado si es visible
    if 380 <= wavelength_nm <= 750:
        color = wavelength_to_rgb(wavelength_nm)
        color_hex = rgb_to_hex(color)
        color_box.config(bg=color_hex)
    else:
        color_box.config(bg="white")


def wavelength_to_rgb(wl):
    """Aproximación simple del color visible según la longitud de onda."""
    if wl < 380 or wl > 750:
        return (255, 255, 255)

    if 380 <= wl < 440:
        r = -(wl - 440) / (440 - 380)
        g = 0
        b = 1
    elif 440 <= wl < 490:
        r = 0
        g = (wl - 440) / (490 - 440)
        b = 1
    elif 490 <= wl < 510:
        r = 0
        g = 1
        b = -(wl - 510) / (510 - 490)
    elif 510 <= wl < 580:
        r = (wl - 510) / (580 - 510)
        g = 1
        b = 0
    elif 580 <= wl < 645:
        r = 1
        g = -(wl - 645) / (645 - 580)
        b = 0
    else:
        r = 1
        g = 0
        b = 0

    return (int(r * 255), int(g * 255), int(b * 255))


def rgb_to_hex(rgb):
    return "#%02x%02x%02x" % rgb


# ---------------- GUI ----------------

root = tk.Tk()
root.title("Transiciones Atómicas del Hidrógeno")
root.geometry("400x450")

tk.Label(root, text="Nivel inicial (m):").pack()
entry_m = tk.Entry(root)
entry_m.pack()

tk.Label(root, text="Nivel final (n):").pack()
entry_n = tk.Entry(root)
entry_n.pack()

btn = tk.Button(root, text="Calcular", command=calcular_transicion)
btn.pack(pady=10)

label_result = tk.Label(root, text="", font=("Arial", 12))
label_result.pack(pady=10)

tk.Label(root, text="Color (si visible):").pack()
color_box = tk.Label(root, width=20, height=2, bg="white", relief="solid")
color_box.pack(pady=5)

root.mainloop()
