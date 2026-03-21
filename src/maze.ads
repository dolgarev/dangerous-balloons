with Settings;

package Maze is

   type Cell_Type is (Empty, Wall, Brick);
   
   Max_Rows : constant Positive := Settings.Max_Rows;
   Max_Cols : constant Positive := Settings.Max_Cols;
   
   type Grid_Type is array (1 .. Max_Rows, 1 .. Max_Cols) of Cell_Type;
   
   procedure Generate (Grid : out Grid_Type);

end Maze;
