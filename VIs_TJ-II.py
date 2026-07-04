from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

#escrito por: Adrián Cabero González 03/07/2026 con ayuda de la IA 

def normalizar_numero(valor: str):
    """
    Convierte numeros con coma decimal a float.
    Ejemplos: '320,01' -> 320.01 ; '293,992' -> 293.992
    """
    if valor is None:
        return None
    texto = str(valor).strip()
    if texto == '':
        return None
    texto = texto.replace(',', '.')
    try:
        return float(texto)
    except ValueError:
        return None


def resolver_archivo(ubicacion: str, disparo: str) -> Path:
    """Acepta ruta directa a TXT o carpeta. Si es carpeta, busca el disparo."""
    ruta = Path(ubicacion).expanduser()

    if ruta.is_file():
        return ruta

    if not ruta.exists():
        raise FileNotFoundError(f'No existe la ruta indicada: {ruta}')

    if not ruta.is_dir():
        raise ValueError(f'La ruta indicada no es ni archivo ni carpeta: {ruta}')

    archivos_txt = sorted(ruta.glob('*.txt'))
    if not archivos_txt:
        raise FileNotFoundError(f'No se han encontrado archivos .txt en la carpeta: {ruta}')

    candidatos_nombre = [f for f in archivos_txt if disparo in f.name]
    if len(candidatos_nombre) == 1:
        return candidatos_nombre[0]
    if len(candidatos_nombre) > 1:
        print('Se han encontrado varios TXT con el disparo en el nombre:')
        for i, f in enumerate(candidatos_nombre, start=1):
            print(f'  {i}) {f.name}')
        idx = int(input('Elige el numero de archivo que quieres leer: ').strip()) - 1
        return candidatos_nombre[idx]

    candidatos_contenido = []
    for f in archivos_txt:
        try:
            texto = f.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue
        if disparo in texto:
            candidatos_contenido.append(f)

    if len(candidatos_contenido) == 1:
        return candidatos_contenido[0]
    if len(candidatos_contenido) > 1:
        print('Se han encontrado varios TXT que contienen el disparo en el texto:')
        for i, f in enumerate(candidatos_contenido, start=1):
            print(f'  {i}) {f.name}')
        idx = int(input('Elige el numero de archivo que quieres leer: ').strip()) - 1
        return candidatos_contenido[idx]

    raise FileNotFoundError(
        f'No se encontro ningun TXT asociado al disparo {disparo} en la carpeta {ruta}'
    )


def leer_txt_6_sensores(ruta_txt: str):
    """
    Lee un TXT de espectrometro con metadatos y tabla separada por ';'.

    Usa:
      - primera columna [nm] como eje x
      - columnas Scan 1 ... Scan 6 como seis sensores/escaneos

    Ignora Dark, Reference, Samples y cualquier otra columna no necesaria.
    """
    ruta = Path(ruta_txt)
    if not ruta.exists():
        raise FileNotFoundError(f'No existe el archivo: {ruta}')

    lineas = ruta.read_text(encoding='utf-8', errors='ignore').splitlines()

    idx_header = None
    for i, linea in enumerate(lineas):
        limpia = linea.strip()
        if '[nm]' in limpia and 'Scan 1' in limpia and 'Scan 6' in limpia:
            idx_header = i
            break

    if idx_header is None:
        raise ValueError('No se encontro la cabecera con [nm] y Scan 1 ... Scan 6.')

    header = [x.strip() for x in lineas[idx_header].split(';')]

    col_nm = None
    cols_scan = []

    for j, nombre in enumerate(header):
        nombre_limpio = nombre.strip()
        if nombre_limpio == '[nm]' or nombre_limpio.lower() == 'nm':
            col_nm = j
        if nombre_limpio.lower().startswith('scan'):
            cols_scan.append(j)

    if col_nm is None:
        raise ValueError('No se pudo localizar la columna de longitud de onda [nm].')

    if len(cols_scan) < 6:
        raise ValueError(f'Se esperaban 6 columnas Scan, pero solo se encontraron {len(cols_scan)}.')

    cols_scan = cols_scan[:6]
    registros = []

    for linea in lineas[idx_header + 1:]:
        if not linea.strip():
            continue

        partes = [x.strip() for x in linea.split(';')]
        n_necesario = max([col_nm] + cols_scan) + 1

        if len(partes) < n_necesario:
            continue

        nm = normalizar_numero(partes[col_nm])
        valores_scan = [normalizar_numero(partes[c]) for c in cols_scan]

        if nm is None:
            continue
        if any(v is None for v in valores_scan):
            continue

        registros.append([nm] + valores_scan)

    if not registros:
        raise ValueError('No se encontraron filas numericas validas para nm y Scan 1..6.')

    columnas = ['nm'] + [f'Scan {i}' for i in range(1, 7)]
    df = pd.DataFrame(registros, columns=columnas)
    df = df.sort_values('nm').reset_index(drop=True)
    return df


def graficar_6_sensores(df: pd.DataFrame, ruta_txt: str, disparo: str):
    """Plotea los seis sensores/Scan frente a longitud de onda."""
    fig, ax = plt.subplots(figsize=(12, 6.5))

    for i in range(1, 7):
        col = f'Scan {i}'
        ax.plot(df['nm'], df[col], linewidth=1.2, label=col)

    ax.set_xlabel('Longitud de onda [nm]')
    ax.set_ylabel('Señal sensor [counts]')
    ax.set_title(f'Espectro visible - 6 sensores | disparo {disparo}')
    ax.grid(True, alpha=0.3)
    ax.legend(loc='best')
    fig.tight_layout()

    ruta_base = Path(ruta_txt)
    nombre_png = ruta_base.with_name(ruta_base.stem + f'__shot_{disparo}__6_sensores.png')
    plt.savefig(nombre_png, dpi=150)
    print(f'Imagen guardada en: {nombre_png}')

    plt.show()


def main():
    print('Programa para graficar Scan 1..6 frente a longitud de onda')
    print('Puedes escribir la ruta directa a un TXT o una carpeta donde buscar el TXT.')

    ubicacion = input('Escribe la ruta del archivo TXT o de la carpeta: ').strip().strip('"')
    disparo = input('Escribe el numero de disparo: ').strip()

    if not ubicacion:
        print('No se ha introducido ninguna ruta.')
        return
    if not disparo:
        print('No se ha introducido ningun disparo.')
        return

    try:
        ruta_txt = resolver_archivo(ubicacion, disparo)
        print(f'Archivo seleccionado: {ruta_txt}')

        df = leer_txt_6_sensores(str(ruta_txt))
        print(f'Archivo leido correctamente. Filas validas: {len(df)}')
        print('Columnas representadas:', ', '.join([f'Scan {i}' for i in range(1, 7)]))

        graficar_6_sensores(df, str(ruta_txt), disparo)

    except Exception as e:
        print(f'Error: {e}')


if __name__ == '__main__':
    main()
