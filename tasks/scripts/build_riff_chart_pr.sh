#!/bin/bash

set -exuo pipefail

build_root=$PWD

source "$build_root/git-pfs-ci/tasks/scripts/common.sh"

cp -pr $build_root/git-helm-charts $build_root/riff

pushd $build_root/git-helm-charts

  helm init --client-only

  # override pull policy for PRs, since the name PR version can easily have multiple commits
  sed -i -e 's/IfNotPresent/Always/g' "$build_root/git-helm-charts/riff/values.yaml"

  function_controller_version=$(determine_riff_version "$build_root/git-function-controller-pr" "$build_root/function-controller-version")
  function_sidecar_version=$(determine_riff_version "$build_root/git-function-sidecar-pr" "$build_root/function-sidecar-version")
  topic_controller_version=$(determine_riff_version "$build_root/git-topic-controller-pr" "$build_root/topic-controller-version")
  http_gateway_version=$(determine_riff_version "$build_root/git-http-gateway-pr" "$build_root/http-gateway-version")

  chart_name=""
  chart_version=""
  set +e
    echo "$function_controller_version" | grep pr
    if [ 0 -eq $? ]; then
      suffix=$(echo "$function_controller_version" | cut -d'-' -f2)
      chart_name="rifffctl${suffix}"
      chart_version="${function_controller_version}"
    else
      echo "$function_sidecar_version" | grep pr
      if [ 0 -eq $? ]; then
        suffix=$(echo "$function_sidecar_version" | cut -d'-' -f2)
        chart_name="rifffsdcr${suffix}"
        chart_version="${function_sidecar_version}"
      else
        echo "$topic_controller_version" | grep pr
        if [ 0 -eq $? ]; then
          suffix=$(echo "$topic_controller_version" | cut -d'-' -f2)
          chart_name="rifftctrl${suffix}"
          chart_version="${topic_controller_version}"
        else
          echo "$http_gateway_version" | grep pr
          if [ 0 -eq $? ]; then
            suffix=$(echo "$http_gateway_version" | cut -d'-' -f2)
            chart_name="riffhttpgw${suffix}"
            chart_version="${http_gateway_version}"
          else
            echo "Failed to determine PR riff component"
            exit 1
          fi
        fi
      fi
    fi
  set -e

  if [ -z $chart_name ]; then
    echo "Failed to determine PR chart name"
    exit 1
  fi

  if [ -z $chart_version ]; then
    echo "Failed to determine PR chart version"
    exit 1
  fi

  cat "$build_root/git-helm-charts/riff/Chart.yaml" | sed -e "s/name: riff/name: $chart_name/g" -e "s/version.*/version: $chart_version/g" > "$build_root/git-helm-charts/riff/Chart.yaml.new"

  mv riff "$chart_name"

  mv "$build_root/git-helm-charts/$chart_name/Chart.yaml.new" "$build_root/git-helm-charts/$chart_name/Chart.yaml"

  helm package "$chart_name" --version "$chart_version"

  chart_file=$(basename ${chart_name}*tgz)

  cat > "${build_root}/helm-charts-install/${chart_name}-${chart_version}-install-example.sh" << EOM
#!/bin/bash

script_name=\`basename "\$0"\`

set -euo pipefail

if (( \$# < 1 )); then
    echo
    echo "Usage:"
    echo
    echo "   \$script_name <chart-name> <extra-helm-args>"
    echo
    exit 1
fi

set -x

chart_name="\$1"
shift

helm install "\${chart_name}" \
--version="${chart_version}" \
--set functionController.image.tag=${function_controller_version},functionController.sidecar.image.tag=${function_sidecar_version},topicController.image.tag=${topic_controller_version},httpGateway.image.tag=${http_gateway_version} \
"\$@"

EOM

  cp "$chart_file" "$build_root/helm-charts/"

  set +e
  curl -sfL "$HELM_CHARTS_URL/index.yaml" > existing_index.yaml
  if [ "0" != "$?" ]; then
    rm -f existing_index.yaml
  fi
  set -e

  if [ -f existing_index.yaml ]; then
    helm repo index "$build_root/helm-charts" --url "$HELM_CHARTS_URL" --merge existing_index.yaml
  else
    helm repo index "$build_root/helm-charts" --url "$HELM_CHARTS_URL"
  fi

  echo "$chart_version" > "$build_root/helm-charts-latest-version/latest_version"
  echo "$chart_name" > "$build_root/helm-charts-latest-name/latest_name"

popd
