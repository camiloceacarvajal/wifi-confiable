# wifi-confiable

Omite la contraseña de desbloqueo cuando el portátil está asociado a tu wifi de casa.

## Qué hace exactamente

Añade **una línea** a `/etc/pam.d/cosmic-greeter` (el archivo PAM que usan tanto la
pantalla de bloqueo como el login de COSMIC). Esa línea ejecuta
`/usr/local/sbin/wifi-confiable`, que responde sí/no. Si dice que sí, PAM da la
autenticación por buena; si dice que no —o si falla por lo que sea— se cae a la
contraseña de siempre.

## Qué comprueba antes de decir que sí

1. El usuario está en `USERS`.
2. `MODE=unlock`: el usuario ya tiene sesión abierta (o sea, es un desbloqueo, no
   un login desde cero).
3. `iw dev` reporta el **SSID** *y* el **BSSID** (MAC del router) esperados.
4. NetworkManager confirma que el perfil activo es una red **cifrada**
   (`wpa-psk`/`sae`/`wpa-eap`).

El punto 4 es el que sostiene todo lo demás. El SSID se falsifica en diez segundos:
cualquiera monta un AP abierto llamado `MiRedDeCasa` y entrarías. Pero el handshake de
WPA2 es mutuo — el AP tiene que demostrar que conoce la PSK para que la
asociación llegue a completarse. Estar asociado a la red cifrada `MiRedDeCasa` es prueba
criptográfica de que ese router es el tuyo, no una imitación.

La PSK vive en `/etc/NetworkManager/system-connections/`, dentro del disco LUKS.
Quien te robe el portátil suspendido no puede leerla sin apagarlo, y si lo apaga
se topa con la contraseña de cifrado. Ahí está el límite real de esta protección.

## Instalar

```
sudo ~/Documentos/wifi-confiable/instalar.sh
```

## Quitar

```
sudo ~/Documentos/wifi-confiable/instalar.sh --quitar
```

## Probar sin arriesgar nada

```
sudo /usr/local/sbin/wifi-confiable --test tuusuario
```

Dice `OK: ...` o `DENEGADO: <motivo>`. Cada decisión real queda además en el
journal:

```
journalctl -t wifi-confiable -n 20
```

## Si algo sale mal

No hay riesgo de quedarte fuera: la línea es `sufficient`, así que un fallo del
script no bloquea nada, solo te devuelve al prompt de contraseña. Y `/etc/pam.d/login`
(las TTY de `Ctrl+Alt+F3`) no se toca, así que siempre hay una puerta trasera legítima.
El instalador guarda copia con fecha del archivo PAM antes de editarlo y se
revierte solo si la edición no queda exacta.

Un aviso por si tocas el script: **PAM lo ejecuta con un `PATH` que no incluye
`/usr/sbin`**, y ahí es donde vive `iw`. Por eso el script fija su propio `PATH`
en la primera línea. Sin eso funciona perfecto desde la terminal y falla siempre
en la pantalla de bloqueo, que es el peor tipo de fallo posible. Para reproducir
el entorno real:

```
env -i PATH=/usr/bin:/bin PAM_USER=tuusuario /usr/local/sbin/wifi-confiable --test tuusuario
```

## Lo que NO hace

No desbloquea sin tocar nada. Sigues teniendo que pulsar Intro en la pantalla de
bloqueo — lo que desaparece es escribir la contraseña. COSMIC no expone ninguna
forma de descartar el bloqueo por programa (`cosmic-comp` no implementa
`UnlockSession` de logind), así que no hay manera de saltarse esa tecla.
