defmodule AshGraphql.Api do
  @graphql %Ash.Dsl.Section{
    name: :graphql,
    describe: """
    Global configuration for graphql
    """,
    examples: [
      """
      graphql do
        authorize? false # To skip authorization for this API
      end
      """
    ],
    schema: [
      authorize?: [
        type: :boolean,
        doc: "Whether or not to perform authorization for this API",
        default: true
      ],
      root_level_errors?: [
        type: :boolean,
        default: false,
        doc:
          "By default, mutation errors are shown in their result object's errors key, but this setting places those errors in the top level errors list"
      ],
      show_raised_errors?: [
        type: :boolean,
        default: false,
        doc:
          "For security purposes, if an error is *raised* then Ash simply shows a generic error. If you want to show those errors, set this to true."
      ],
      stacktraces?: [
        type: :boolean,
        doc: "Whether or not to include stacktraces in generated errors",
        default: true
      ],
      debug?: [
        type: :boolean,
        doc: "Whether or not to log (extremely verbose) debug information",
        default: false
      ]
    ]
  }

  @sections [@graphql]

  @moduledoc """
  The entrypoint for adding graphql behavior to an Ash API

  # Table of Contents
  #{Ash.Dsl.Extension.doc_index(@sections)}

  #{Ash.Dsl.Extension.doc(@sections)}
  """

  use Ash.Dsl.Extension, sections: @sections

  def authorize?(api) do
    Extension.get_opt(api, [:graphql], :authorize?, true)
  end

  def root_level_errors?(api) do
    Extension.get_opt(api, [:graphql], :root_level_errors?, false, true)
  end

  def show_raised_errors?(api) do
    Extension.get_opt(api, [:graphql], :show_raised_errors?, false, true)
  end

  def debug?(api) do
    Extension.get_opt(api, [:graphql], :debug?, false)
  end

  def stacktraces?(api) do
    Extension.get_opt(api, [:graphql], :stacktraces?, false)
  end

  @doc false
  def queries(api, schema) do
    api
    |> Ash.Api.resources()
    |> Enum.flat_map(&AshGraphql.Resource.queries(api, &1, schema))
  end

  @doc false
  def mutations(api, schema) do
    api
    |> Ash.Api.resources()
    |> Enum.filter(fn resource ->
      AshGraphql.Resource in Ash.Resource.Info.extensions(resource)
    end)
    |> Enum.flat_map(&AshGraphql.Resource.mutations(api, &1, schema))
  end

  @doc false
  def type_definitions(api, schema) do
    resource_types =
      api
      |> Ash.Api.resources()
      |> Enum.flat_map(fn resource ->
        if AshGraphql.Resource in Ash.Resource.Info.extensions(resource) do
          AshGraphql.Resource.type_definitions(resource, api, schema) ++
            AshGraphql.Resource.mutation_types(resource, schema)
        else
          AshGraphql.Resource.no_graphql_types(resource, schema)
        end
      end)

    if Enum.any?(Ash.Api.resources(api), &AshGraphql.Resource.relay?/1) do
      %Absinthe.Blueprint.Schema.InterfaceTypeDefinition{
        description: "A relay node",
        name: "Node",
        fields: [
          %Absinthe.Blueprint.Schema.FieldDefinition{
            description: "A unique identifier",
            identifier: :id,
            module: schema,
            name: "id",
            type: %Absinthe.Blueprint.TypeReference.NonNull{of_type: :id}
          }
        ],
        identifier: :node,
        module: schema
      }
    else
      resource_types
    end
  end

  def global_type_definitions(schema) do
    [mutation_error(schema), sort_order(schema)]
  end

  defp sort_order(schema) do
    %Absinthe.Blueprint.Schema.EnumTypeDefinition{
      module: schema,
      name: "SortOrder",
      values: [
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :desc,
          name: "DESC",
          value: :desc
        },
        %Absinthe.Blueprint.Schema.EnumValueDefinition{
          module: schema,
          identifier: :asc,
          name: "ASC",
          value: :asc
        }
      ],
      identifier: :sort_order
    }
  end

  defp mutation_error(schema) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "An error generated by a failed mutation",
      fields: error_fields(schema),
      identifier: :mutation_error,
      module: schema,
      name: "MutationError"
    }
  end

  defp error_fields(schema) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The human readable error message",
        identifier: :message,
        module: schema,
        name: "message",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "A shorter error message, with vars not replaced",
        identifier: :short_message,
        module: schema,
        name: "short_message",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Replacements for the short message",
        identifier: :vars,
        module: schema,
        name: "vars",
        type: :json
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "An error code for the given error",
        identifier: :code,
        module: schema,
        name: "code",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The field or fields that produced the error",
        identifier: :fields,
        module: schema,
        name: "fields",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: :string
        }
      }
    ]
  end
end
