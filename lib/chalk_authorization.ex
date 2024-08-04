defmodule ChalkAuthorization do
  @moduledoc """
  Chalk is an authorization module with support for roles that can handle configurable
  custom actions and permissions. It also supports user and group based authorization.

  It is inspired in the UNIX file permissions.

  `ChalkAuthorization` provides the next:
  - `can?/3` to check if the user is allowed to perform an specific
  action on a specific element.
  - `is_a?/2` to check if the user belongs to a specific group.
  - A set of functions to manage the user's permissions and groups.

  ## Implementing `ChalkAuthorization`

  Once you installed the package, you can add it to any model.
  `ChalkAuthorization` is developed with Ecto in mind, although it may
  be possible to adapt it to use other solutions.

  See the ["Setup" section on the README](readme.html#setup).

  ## `opts` parameters

  Available options are:

  - `repo`: it is mandatory to specify the Ecto's repository you want to use.
  - `group_permissions`: it is mandatory to specify a map to indicate the groups,
  their actions and what their members are allowed to do.

  ## Usage

  - TLDR: ["Usage" section on the README](readme.html#usage).
  - Take a look at the [functions cheatsheet](functions.html).
  """

  @doc """
  TODO: extract this documentation from the `__using__` macro into the cheatsheet `Functions`.
  Chalk integrates the next functions to handle the authorization system.

  ## `permission_map`

  Get the translation between a permission and its integer representation.

  ## `permission_changeset(item, attrs)`

  Get the changeset to update the permissions.

  - `item` can be an atom or a string.
  - `attrs` can be a...

  ## `can?(user, permission, element)`

  Check if a user has permission to perform an action on a specific element.

  ### Parameters

  - `user` can be a map or nil.
  - `permission` and `element`, both can be an atom or a string.

  ## `get_permissions(user, element)`

  Get the permissions of a user on an element.

  ### Parameters

  - `user` can be a map.
  - `element` can be an atom or a string.

  ## `add_group(user, group)`

  Add a user to a specific group.

  ### Parameters

  - `user` can be a map.
  - `group` can be a string or a list of groups.

  ## `remove_group(user, group)

  Add a user to a specific group.

  ### Parameters

  - `user` can be a map.
  - `group` can be a string or a list of groups.

  ## `is_a?(user, group)

  Check if the user is in a specific group.

  ### Parameters

  - `user` can be a map.
  - `groups` can be a string, a bitstring or a list of groups.

  ## set_permissions(user, element)

  Grant permissions to a user on an item.

  ### Parameters

  - `user` can be a map.
  - `element` can be an atom or a string. `value` can
  be an integer or a string.

  ## set_superuser(user, boolean)

  Grant or revoke a user the role of superuser (all permissions).

  ### Parameters

  - `user` can be a map.
  - `boolean` can be `true` or `false`.

  """
  defmacro __using__(repo: repo, group_permissions: group_permissions) do
    quote do
      @doc """
      Get the translation between a permission and its integer representation
      """
      def permission_map,
        do: Application.get_env(:chalk_authorization, :permission_map, %{c: 1, r: 2, u: 4, d: 8})

      @doc """
      Get the changeset to update the permissions.

      ### Parameters

      - `item`: can be an atom or a string.
      - `attrs`: can be a map.
      """
      def permissions_changeset(item, attrs),
        do: cast(item, attrs, [:superuser, :groups, :permissions])

      @doc """
      Check if a user has permission to perform an action on a specific element.

      ## Parameters

      - `user`: can be a map or `nil`.
      - `permission`: can be an atom or a string.
      - `element`: can be an atom or a string.

      ## Returns

      `true` or `false`.
      """
      def can?(nil, _permission, _element),
        do: false

      def can?(user, permission, element) when is_atom(permission),
        do: can?(user, Atom.to_string(permission), element)

      def can?(%{superuser: true}, _permission, _element),
        do: true

      def can?(%{groups: [group | groups]} = user, permission, element),
        do:
          user
          |> get_group_permissions(group)
          |> Map.put(:groups, groups)
          |> can?(permission, element)

      def can?(user, permission, element),
        do:
          user
          |> get_permissions(Atom.to_string(element))
          |> permissions_int_to_string
          |> String.contains?(permission)

      """
      Get the permissions of a specific group and upgrade the user's
      permissions according to the ones given to the group.
      """

      defp get_group_permissions(),
        do: unquote(group_permissions) || %{}

      defp get_group_permissions(user, group),
        do:
          if(
            Map.has_key?(get_group_permissions(), group) &&
              Enum.member?(user.groups, group),
            do: upgrade_to_group(user, Map.get(get_group_permissions(), group)),
            else: user
          )

      """
      Upgrade the users permissions according to the ones given
      to the group. If the user has higher permissions than the
      group given or the user is in a group with higher permissions,
      the permissions aren't upgraded.
      """

      defp upgrade_to_group(%{permissions: permissions} = user, group_permissions),
        do:
          Map.put(
            user,
            :permissions,
            upgrade_to_group(permissions, Map.to_list(group_permissions))
          )

      defp upgrade_to_group(permissions, []),
        do: permissions

      defp upgrade_to_group(permissions, [{permission, value} | group_permissions]),
        do:
          if(
            Map.has_key?(permissions, permission) &&
              permissions[permission] >= value,
            do: permissions,
            else:
              Map.put(permissions, permission, value)
              |> upgrade_to_group(group_permissions)
          )

      @doc """
      Get the permissions of a user on an element.

      ## Parameters

      - `user` can be a map.
      - `element` can be an atom or a string.

      ## Returns

      The permission of the user or `0`.
      """
      def get_permissions(user, element) when is_atom(element),
        do: get_permissions(user, Atom.to_string(element))

      def get_permissions(user, element),
        do:
          if(Map.has_key?(user.permissions, element),
            do: user.permissions[element],
            else: 0
          )

      @doc """
      Add a user to a specific group.

      ## Parameters

      - `user` can be a map.
      - `group` can be a string or a list of groups.

      ## Returns

      The group or groups added to the user.
      """
      def add_group(user, []),
        do: user

      def add_group(user, [group | groups]),
        do: add_group(add_group(user, group), groups)

      def add_group(user, group) when not is_bitstring(group),
        do: add_group(user, "#{group}")

      def add_group(%{groups: groups} = user, group),
        do:
          user
          |> __MODULE__.permissions_changeset(%{
            groups: (groups ++ [group]) |> Enum.sort() |> Enum.uniq()
          })
          |> unquote(repo).update()
          |> elem(1)

      @doc """
      Remove a user from a specific group.

      ## Parameters

      - `user` can be a map.
      - `group` can be a string, a bitstring or a list of groups.

      ## Returns

      The group or groups added to the user.
      """
      def remove_group(user, []),
        do: user

      def remove_group(user, [group | groups]),
        do: remove_group(remove_group(user, group), groups)

      def remove_group(user, group) when not is_bitstring(group),
        do: remove_group(user, "#{group}")

      def remove_group(%{groups: groups} = user, group),
        do:
          user
          |> __MODULE__.permissions_changeset(%{
            groups: Enum.reject(groups, fn g -> g == group end)
          })
          |> unquote(repo).update()
          |> elem(1)

      @doc """
      Check if the user is in a specific group.

      ## Parameters

      - `user` can be a map.
      - `groups` can be a string, a bitstring or a list of groups.

      ## Returns

      `true` or `false`.
      """
      def is_a?(user, groups) when is_list(groups),
        do: groups |> Enum.all?(fn g -> user |> is_a?(g) end)

      def is_a?(user, group) when not is_bitstring(group),
        do: is_a?(user, "#{group}")

      def is_a?(%{groups: groups}, group),
        do: Enum.member?(groups, group)

      @doc """
      Grant permissions to a user on an item.

      ## Parameters

      - `user` can be a map.
      - `element` can be an atom or a string. `value` can
      be an integer or a string.

      ## Returns

      The `repo` updated or an error.
      """
      def set_permissions(user, element, value) when is_atom(element),
        do: set_permissions(user, Atom.to_string(element), value)

      def set_permissions(user, element, value) when is_integer(value) do
        if value >= 0 and value <= Enum.sum(Map.values(permission_map())) do
          user
          |> __MODULE__.permissions_changeset(%{
            permissions: Map.put(user.permissions, element, value)
          })
          |> unquote(repo).update()
        else
          {:error, user}
        end
      end

      def set_permissions(user, element, value) do
        case value do
          "+" <> permissions ->
            set_permissions(
              user,
              element,
              get_permissions(user, element) + permissions_string_to_int(permissions)
            )

          "-" <> permissions ->
            set_permissions(
              user,
              element,
              get_permissions(user, element) - permissions_string_to_int(permissions)
            )

          _ ->
            set_permissions(user, element, permissions_string_to_int(value))
        end
      end

      """
      Convert a string of permissions into an integer.
      """

      defp permissions_string_to_int(string) do
        string
        |> String.graphemes()
        |> Enum.uniq()
        |> Enum.map(fn p -> permission_map()[String.to_atom(p)] end)
        |> Enum.sum()
      end

      """
      Convert an integer permission into a string.
      """

      defp permissions_int_to_string(int) when is_integer(int) do
        keys =
          Map.keys(permission_map())
          |> Enum.sort_by(fn k -> permission_map()[k] end)
          |> Enum.reverse()

        permissions_int_to_string(int, keys, [])
      end

      defp permissions_int_to_string(rest, [], acc) do
        cond do
          rest == 0 ->
            acc |> Enum.map(fn a -> Atom.to_string(a) end) |> Enum.join()

          true ->
            :error
        end
      end

      defp permissions_int_to_string(rest, [key | tail], acc) do
        if rest - permission_map()[key] >= 0 do
          permissions_int_to_string(rest - permission_map()[key], tail, [key | acc])
        else
          permissions_int_to_string(rest, tail, acc)
        end
      end

      @doc """
      Grant or revoke a user the role of superuser (all permissions).

      ## Parameters

      - `user` can be a map.
      - `boolean` can be `true` or `false`.

      ## Returns

      `true` or `false`.
      """
      def set_superuser(%{superuser: _} = user, boolean) when is_boolean(boolean),
        do:
          user
          |> __MODULE__.permissions_changeset(%{superuser: boolean})
          |> unquote(repo).update()
          |> elem(1)
    end
  end
end
