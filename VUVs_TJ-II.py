import os
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

#escrito por: Adrián Cabero González-Grad_Física-UCLM 03/07/2026 con ayuda de la IA 

# --- Configuración ---
ARCHIVO_POR_DEFECTO = '110626_ 21.csv'
FRAME_INICIAL = 14
FRAME_FINAL = 80
TIEMPO_FRAME_14_MS = 1111.252
DELTA_TIEMPO_MS = 3.259
PIXEL_INICIAL = 1
PIXEL_FINAL = 1340


def calcular_tiempo_ms(frame: int) -> float:
    return TIEMPO_FRAME_14_MS + (frame - FRAME_INICIAL) * DELTA_TIEMPO_MS


def cargar_datos():
    """
    Intenta cargar el CSV desde la misma carpeta que este script.
    Si no lo encuentra, pide al usuario la ruta manualmente.
    """
    carpeta_script = Path(__file__).resolve().parent
    ruta_csv = carpeta_script / ARCHIVO_POR_DEFECTO

    if not ruta_csv.exists():
        print(f'No encuentro el archivo "{ARCHIVO_POR_DEFECTO}" en la misma carpeta que este .py.')
        ruta_manual = input('Escribe la ruta completa del CSV y pulsa Enter: ').strip().strip('"')
        ruta_csv = Path(ruta_manual)

    if not ruta_csv.exists():
        raise FileNotFoundError(f'No se encontró el archivo CSV: {ruta_csv}')

    # Lectura robusta: separadores por espacios o tabuladores
    raw = pd.read_csv(
        ruta_csv,
        sep=r'\s+',
        engine='python',
        names=['Frame', 'Intensity'],
        header=0
    )

    raw['Frame'] = pd.to_numeric(raw['Frame'], errors='coerce')
    raw['Intensity'] = pd.to_numeric(raw['Intensity'], errors='coerce')
    df = raw.dropna(subset=['Frame', 'Intensity']).copy()
    df['Frame'] = df['Frame'].astype(int)

    return df, ruta_csv


def pedir_frame():
    while True:
        entrada = input(f'¿Qué frame quieres mostrar? ({FRAME_INICIAL}-{FRAME_FINAL}): ').strip()
        try:
            frame = int(entrada)
        except ValueError:
            print('Por favor, escribe un número entero válido.')
            continue

        if FRAME_INICIAL <= frame <= FRAME_FINAL:
            return frame
        else:
            print(f'El frame debe estar entre {FRAME_INICIAL} y {FRAME_FINAL}.')


def mostrar_frame(df: pd.DataFrame, frame: int, guardar_png: bool = True):
    datos = df.loc[df['Frame'] == frame, 'Intensity'].reset_index(drop=True)

    if datos.empty:
        print(f'No hay datos para el frame {frame}.')
        return

    n = len(datos)
    x_pixels = np.arange(PIXEL_INICIAL, PIXEL_INICIAL + n)

    # Ejemplo de calibración: ajusta estos valores a tus datos reales.
    coef_lineal = np.polyfit([74, 945.7], [27.775, 43], 1)
    coef_polinomico = np.polyfit([74, 500, 945.7], [27.775, 35, 43], 2)

    x_nm_lineal = np.polyval(coef_lineal, x_pixels)
    x_nm_polinomico = np.polyval(coef_polinomico, x_pixels)

    tiempo_ms = calcular_tiempo_ms(frame)

    # 1) Ajuste lineal
    plt.figure(figsize=(11, 5))
    plt.plot(x_nm_lineal, datos.values, linewidth=1)
    plt.title(f'Frame {frame} | Ajuste lineal | t = {tiempo_ms:.3f} ms')
    plt.xlabel('Longitud de onda (nm)')
    plt.ylabel('Intensidad')
    plt.xlim(x_nm_lineal.min(), x_nm_lineal.max())
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    if guardar_png:
        nombre_lineal = f'UVis_frame_{frame:02d}_lineal.png'
        plt.savefig(nombre_lineal, dpi=150)
        print(f'Imagen guardada como: {nombre_lineal}')
    plt.show()
    plt.close()

    # 2) Ajuste polinómico
    plt.figure(figsize=(11, 5))
    plt.plot(x_nm_polinomico, datos.values, linewidth=1)
    plt.title(f'Frame {frame} | Ajuste polinómico | t = {tiempo_ms:.3f} ms')
    plt.xlabel('Longitud de onda (nm)')
    plt.ylabel('Intensidad')
    plt.xlim(x_nm_polinomico.min(), x_nm_polinomico.max())
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    if guardar_png:
        nombre_polinomico = f'UVis_frame_{frame:02d}_polinomico.png'
        plt.savefig(nombre_polinomico, dpi=150)
        print(f'Imagen guardada como: {nombre_polinomico}')
    plt.show()
    plt.close()

    # 3) Eje X en píxeles
    plt.figure(figsize=(11, 5))
    plt.plot(x_pixels, datos.values, linewidth=1)
    plt.title(f'Frame {frame} | Eje en píxeles | t = {tiempo_ms:.3f} ms')
    plt.xlabel('Píxeles')
    plt.ylabel('Intensidad')
    plt.xlim(PIXEL_INICIAL, PIXEL_FINAL)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    if guardar_png:
        nombre_pixeles = f'UVis_frame_{frame:02d}_pixeles.png'
        plt.savefig(nombre_pixeles, dpi=150)
        print(f'Imagen guardada como: {nombre_pixeles}')
    plt.show()
    plt.close()


if __name__ == '__main__':
    try:
        df, ruta_csv = cargar_datos()
        print(f'Archivo cargado correctamente: {ruta_csv}')
        frame = pedir_frame()
        mostrar_frame(df, frame, guardar_png=False)  # Cambia a True si quieres guardar las imágenes automáticamente
    except Exception as e:
        print(f'Error: {e}')
