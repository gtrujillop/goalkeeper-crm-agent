defmodule StoreCRM.Customers.PhoneTest do
  use ExUnit.Case, async: true
  alias StoreCRM.Customers.Phone

  test "normalizes Colombian local mobile numbers" do
    assert {:ok, "+573001234567"} = Phone.normalize("300 123 4567", "CO")
  end

  test "preserves explicit international regions" do
    assert {:ok, "+34600123456"} = Phone.normalize("+34 600 123 456", "CO")
  end
end
