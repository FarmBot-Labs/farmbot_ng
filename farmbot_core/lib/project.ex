defmodule Farmbot.Project do
  @moduledoc "Farmbot project config"

  @version Mix.Project.config[:version] || "0.1.0"
  @target Mix.Project.config[:target] || "host"
  @commit Mix.Project.config[:commit] || "fixme"
  @arduino_commit Mix.Project.config[:arduino_commit] || "fixme"
  @env Mix.env()

  @doc "*#{@version}*"
  @compile {:inline, version: 0}
  def version, do: @version

  @doc "*#{@commit}*"
  @compile {:inline, commit: 0}
  def commit, do: @commit

  @doc "*#{@arduino_commit}*"
  @compile {:inline, arduino_commit: 0}
  def arduino_commit, do: @arduino_commit

  @doc "*#{@target}*"
  @compile {:inline, target: 0}
  def target, do: @target

  @doc "*#{@env}*"
  @compile {:inline, env: 0}
  def env, do: @env
end
