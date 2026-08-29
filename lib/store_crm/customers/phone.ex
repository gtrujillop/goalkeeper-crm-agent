defmodule StoreCRM.Customers.Phone do
  @moduledoc "Normalizes phone identities without changing explicit international regions."

  def normalize(value, default_region) when is_binary(value) do
    compact = value |> String.trim() |> String.replace(~r/[^\d+]/u, "")

    cond do
      Regex.match?(~r/^\+[1-9]\d{7,14}$/, compact) ->
        {:ok, compact}

      String.starts_with?(compact, "00") ->
        normalize("+" <> String.slice(compact, 2..-1//1), default_region)

      default_region == "CO" ->
        normalize_colombian(compact)

      true ->
        {:error, :invalid_phone_number}
    end
  end

  def normalize(_, _), do: {:error, :invalid_phone_number}
  defp normalize_colombian("57" <> rest) when byte_size(rest) == 10, do: {:ok, "+57" <> rest}
  defp normalize_colombian(number) when byte_size(number) == 10, do: {:ok, "+57" <> number}
  defp normalize_colombian(_), do: {:error, :invalid_phone_number}
end
