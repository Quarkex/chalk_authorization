# Chalk Authorization

Chalk is yet another authorization module with support for roles. It can handle
configurable custom actions and permissions, and also user and group based
authorization. If you look for something similar to UNIX file permissions, this
module is inspired by that.

## Installation

This package is [available in Hex](https://hexdocs.pm/chalk_authorization), and
can be installed by adding `chalk_authorization` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:chalk_authorization, "~> 0.1.1"},
    ...
  ]
end
```

## Setup

Once added to your project, you can enable chalk in any model. To do so include
the following line, changing the values to match your requirements:

```elixir
use ChalkAuthorization,
  repo: MyApp.Repo,
  group_permissions: %{
    "staff" => %{
      "read_only_resource" => 2,
      "restricted_resource" => 15
    },
    "user" => %{
      "restricted_resource" => 2
    }
  }
```

Chalk does expect your model to include the following attributes:

```elixir
field :superuser, :boolean, default: false
field :groups, {:array, :string}, default: []
field :permissions, {:map, :integer}, default: %{}
```

You must include a migration to add these fields to the database
if there are not present already:

```elixir
defmodule MyApp.Repo.Migrations.AddUserAuthorizationFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :superuser, :boolean, default: false, null: false
      add :groups, {:array, :string}, default: [], null: false
      add :permissions, {:map, :integer}, default: "{}", null: false
    end
  end
end
```

## Usage

Chalk follows the naming Elixir convention, so any function ending in "?" will return
a boolean value.

Once your models are configured you can ask them questions. I.E: if you add it
to a `MyApp.User` model you may ask it if it's in the "staff" group like so:

```elixir
MyApp.User.is_a?(current_user, "staff")
```

If instead you want to know if the current user is allowed to "create"
something you may ask it as so:

```elixir
MyApp.User.can?(current_user, :c, "files")
```

The default actions in any resource are CRUD, stored in database as an integer.
This is configurable, by default the equivalences are:

```elixir
%{ c: 1, r: 2, u: 4, d: 8 }
```

I recommend not to alter this, but if you must, you can do so in the config
files like this:

```elixir
    configure :chalk_authorization,
      permission_map: %{
        r: 1,
        w: 2,
        x: 4
      }
```

Per-item resource based permissions are yet not included, but the
implementation should be easy enough.

### Phoenix Plug

If you intent to use it with Phoenix Framework, [there is a plug for
that](https://github.com/Quarkex/chalk_authorization_plug).
