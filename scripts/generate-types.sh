#!/bin/sh

APP_RESOURCES_DIRECTORY=$1

export APP_REVISION=`jq -r '"\(.version)-\(.revision[0:8])"' "$APP_RESOURCES_DIRECTORY/data/version.json"`
export APP_VERSION=`jq -r '.version' "$APP_RESOURCES_DIRECTORY/data/version.json"`
export APP_FULL_REVISION=`jq -r '.revision' "$APP_RESOURCES_DIRECTORY/data/version.json"`
QUERIES_DIRECTORY=$APP_RESOURCES_DIRECTORY/resources-formatted/static/js
QUERIES=`ls $QUERIES_DIRECTORY | grep .graphql. | grep .json`

mkdir -p src/generated
mkdir -p src/generated/named

for file in $QUERIES
do
    id=`jq -r '.params.id' "$QUERIES_DIRECTORY/$file"`
    name=`jq -r '.params.name' "$QUERIES_DIRECTORY/$file"`
    echo "Generating types for GraphQL query $id/$name from module $QUERIES_DIRECTORY/$file from SplatNet 3 $APP_REVISION"

    cat "$QUERIES_DIRECTORY/$file" | node dist/scripts/generate-types.js > src/generated/queries/$id.ts

    echo "export const v_$APP_FULL_REVISION = { id: '$id', name: '$name', app_full_version: '$APP_REVISION', app_version: '$APP_VERSION', app_revision: '$APP_FULL_REVISION' } as { id: '$id', name: '$name', app_full_version: '$APP_REVISION', app_version: '$APP_VERSION', app_revision: '$APP_FULL_REVISION', type: import('../queries/$id.js').default };" >> src/generated/named/$name.ts

    echo ""
done

rm src/generated/{types,latest,named}.ts

GENERATED_TYPES=`ls src/generated/queries | sed -r s/\.ts//`
echo "type generated_types = {" > src/generated/types.ts

for id in $GENERATED_TYPES
do
    echo "    '$id': import('./queries/$id.js').default," >> src/generated/types.ts
done

echo "};" >> src/generated/types.ts
echo "" >> src/generated/types.ts
echo "export default generated_types;" >> src/generated/types.ts
echo "" >> src/generated/types.ts

for id in $GENERATED_TYPES
do
    echo "export * from './queries/$id.js';" >> src/generated/types.ts
done

NAMED_TYPES=`ls src/generated/named | sed -r s/\.ts\$//`

for name in $NAMED_TYPES
do
    echo "export * as $name from './named/$name.js';" >> src/generated/named.ts
done

for file in $QUERIES
do
    id=`jq -r '.params.id' "$QUERIES_DIRECTORY/$file"`
    name=`jq -r '.params.name' "$QUERIES_DIRECTORY/$file"`

    echo "export { default as $name } from './queries/$id.js';" >> src/generated/latest.ts
done
