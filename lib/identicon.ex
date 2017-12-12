defmodule Identicon do
  require Integer

  @grid_size 5
  @cell_size 50

  @moduledoc"""
    Generates an identicon from a given string (presumably a user name).
    An identicon is a 250x250px, 5x5 grid with verital simmetry.
  """

  @doc"""
    The struct describig an identicon.
    - hash: The list of numbers that is a hash of the input string
    - color: an {r, g, b} tuple that holds the fill color to use
    - cells_to_fill: a list of indexes that must be filled with a color
    - pixel_map: a list of {top_left, bottom_right} tuples that represent filled squares in the identicon.
      Each touple item is a touple itself, with {horizontal, vertical} coordinates.
  """
  defstruct hash: nil,
    color: nil,
    cells_to_fill: nil,
    pixel_map: nil

  @doc"""
    Generates an identicon given an input string and saves it in a file.
  """
  def generate_identicon(input) do
    input
    |> hash_input
    |> pick_color
    |> get_filled_cells
    |> build_pixel_map
    |> generate_image
    |> save_image(input)
  end

  @doc"""
    Generates a hash from a given inut string.
    The generated binary hash is converted into a list of 16 numbers (bytes),
    which have the following meaning:
    - First 3 bytes represent an RGB color of the identicon
    - First 15 bytes are used to fill the identicon with empty or full squares

    ## Example
      iex> %Identicon{ hash: hash } = Identicon.hash_input("hey ho")
      iex> hash
      [172, 137, 160, 109, 74, 239, 183, 169, 100, 217, 54, 149, 46, 248, 141, 45]
      iex> assert length(hash) == 16
      true
  """
  def hash_input(input) do
    hash = :crypto.hash(:md5, input)
    |> :binary.bin_to_list

    %Identicon{hash: hash}
  end

  @doc"""
    Enriches a given Identicon struct by setting a color generated from the hash.
    The first 3 numbers of the hash represents an RGB code to use for the identicon.

    ## Example
      iex> Identicon.pick_color %Identicon{ hash: [100, 150, 200] }
      %Identicon{ hash: [100, 150, 200], color: {100, 150, 200} }
  """
  def pick_color(identicon) do
    %Identicon{hash: [r, g, b | _]} = identicon
    %Identicon{identicon | color: {r, g, b}}
  end

  @doc"""
    Given an identicon struct, it generates a list of cells to fill out of its hash.
    The grid cells indices have the following relation with the hash bytes indices:
    ```
    +---+---+---+---+---+
    | 1 | 2 | 3 | 2 | 1 |
    +---+---+---+---+---+
    | 4 | 5 | 6 | 5 | 4 |
    +---+---+---+---+---+
    | 7 | 8 | 9 | 8 | 7 |
    +---+---+---+---+---+
    |10 |11 |12 | 11| 10|
    +---+---+---+---+---+
    |13 |14 |15 | 14| 13|
    +---+---+---+---+---+
    ```
    So the hash [10, 20, 30, 40, 50, ...] would generate the first row that is [ 10 | 20 | 30 | 20 | 10 ] an so on.
    Once we fill the grid with hash values we extract the grid indices that have even values. They'll correspond to filled squares in the final identicon.

    ## Example
      iex> %Identicon{ cells_to_fill: cells_to_fill } = Identicon.get_filled_cells %Identicon{ hash: [172, 137, 160, 109, 74, 239, 183, 169, 100, 217, 54, 149, 46, 248, 141, 45] }
      iex> cells_to_fill
      [0, 2, 4, 6, 8, 12, 16, 18, 20, 21, 23, 24]
  """
  def get_filled_cells(identicon) do
    %Identicon{hash: hash} = identicon

    cells_to_fill = hash
    |> Enum.chunk_every(3)
    |> Enum.take(@grid_size)
    |> Enum.map(fn([first, second, third]) -> [first, second, third, second, first] end)
    |> List.flatten
    |> Enum.with_index
    |> Enum.filter(fn({value, _}) -> Integer.is_even(value) end)
    |> Enum.map(fn({_, index}) -> index end)

    %Identicon{identicon | cells_to_fill: cells_to_fill}
  end

  @doc"""
    Given an identicon struct, it generates the pixel map out of the filled cells indices.
    A pixel map is a list of coordinates of top-left and bottom-righ points of a filled square.
    It will be used to draw an actual image.

    ## Example
      iex> %Identicon{ pixel_map: pixel_map } = Identicon.build_pixel_map %Identicon{ cells_to_fill: [0, 12, 24] }
      iex> pixel_map
      [ {{0, 0}, {50, 50}}, {{100, 100}, {150, 150}}, {{200, 200}, {250, 250}} ]
  """
  def build_pixel_map(identicon) do
    %Identicon{cells_to_fill: cells_to_fill} = identicon

    pixel_map = Enum.map cells_to_fill, fn(index) ->
      horizontal = rem(index, @grid_size) * @cell_size
      vertical = div(index, @grid_size) * @cell_size

      top_left = {horizontal, vertical}
      bottom_right = {horizontal + @cell_size, vertical + @cell_size}

      {top_left, bottom_right}
    end

    %Identicon{identicon | pixel_map: pixel_map}
  end

  @doc"""
    Given an identicon it generates an actual identicon PNG image.
    An identicon is composed by drawing a white background in the first place,
    and then by drawing multiple squares filled with a color usingn pixel map coordinates.
  """
  def generate_image(%Identicon{color: color, pixel_map: pixel_map}) do
    image_size = @grid_size * @cell_size
    image = :egd.create image_size, image_size
    fill = :egd.color color

    Enum.each pixel_map, fn({top_left, bottom_right}) ->
      :egd.filledRectangle image, top_left, bottom_right, fill
    end

    :egd.render image
  end

  @doc"""
    Persists the generated identicon in a file in the file system.
  """
  def save_image(image, file_name) do
    File.write "#{file_name}.png", image
  end

end
