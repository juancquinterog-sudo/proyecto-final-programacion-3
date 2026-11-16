import Config

# Carpeta donde se guardan los archivos de texto plano (persistencia).
config :emergencias, data_dir: "data"

import_config "#{config_env()}.exs"
