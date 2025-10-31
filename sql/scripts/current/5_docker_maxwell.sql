

sudo docker run --rm --name maxwell --network host \
  zendesk/maxwell \
  bin/maxwell \
  --host=127.0.0.1 --user=maxwell --password='lol800mt2' \
  --schema_database=maxwell \
  --filter='include: JWX.*' \
  --output_ddl=true \
  --output_primary_keys=true \
  --bootstrapper=sync \
  --log_level=info
