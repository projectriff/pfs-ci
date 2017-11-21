#!/bin/bash

function init_kubeconfig(){
  if [ ! -z "$KUBECONFIG_STRING" ]; then
    mkdir ~/.kube
    echo "$KUBECONFIG_STRING" > ~/.kube/config
  fi
}

function init_docker(){
  if [ ! -z "$KUBECONFIG_STRING" ]; then
    start_docker
  fi
}

function generate_tiller_ns_name(){
  local _sk8s_version="$1"
  local _suffix="$2"
  local _sanitized_version=$(echo "$_sk8s_version" | sed 's/\./-/g' |  awk '{print tolower($0)}')
  echo "tiller-${_sanitized_version}-${_suffix}"
}

function generate_sk8s_ns_name(){
  local _sk8s_version="$1"
  local _suffix="$2"
  local _sanitized_version=$(echo "$_sk8s_version" | sed 's/\./-/g' |  awk '{print tolower($0)}')
  echo "sk8s-${_sanitized_version}-${_suffix}"
}

function find_existing_tiller_ns(){
  local _sk8s_version="$1"
  local _sanitized_version=$(echo "$_sk8s_version" | sed 's/\./-/g' |  awk '{print tolower($0)}')

  set +e
  existing_tiller_ns_name=$(kubectl get ns | grep "tiller-${_sanitized_version}-" | awk '{print $1}')
  set -e
  echo "$existing_tiller_ns_name"
}

function find_existing_sk8s_ns(){
  local _sk8s_version="$1"
  local _sanitized_version=$(echo "$_sk8s_version" | sed 's/\./-/g' |  awk '{print tolower($0)}')

  set +e
  existing_sk8s_ns_name=$(kubectl get ns | grep "sk8s-${_sanitized_version}-" | awk '{print $1}')
  set -e
  echo "$existing_sk8s_ns_name"
}

function determine_sk8s_version(){
  local _sk8s_git_dir="$1"
  local _sk8s_version_dir="$2"
  local _sk8s_version=$(head "$_sk8s_version_dir/version")

  cd "$_sk8s_git_dir"
  set +e
  local _pr_number=$(git config --local --get pullrequest.id)
  set -e

  if [ -z "$_pr_number" ]; then
    echo "$_sk8s_version"
  else
    echo "0.0.0-pr${_pr_number}"
  fi
}

function strip_snapshot_from_version(){
  echo "$1" | awk -F'-' '{print $1}'
}
