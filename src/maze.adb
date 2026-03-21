with Ada.Numerics.Discrete_Random;

package body Maze is

   procedure Generate (Grid : out Grid_Type) is
      subtype Prob_Range is Integer range 1 .. 100;
      package Random_Prob is new Ada.Numerics.Discrete_Random (Prob_Range);
      Gen : Random_Prob.Generator;
      Brick_Probability : constant Integer := 40; -- Probability to spawn a brick adjacent to a wall
      
      procedure Try_Place_Brick (R, C : Integer) is
      begin
         if R > 1 and then R < Max_Rows and then C > 1 and then C < Max_Cols then
            if Grid (R, C) = Empty then
               if Random_Prob.Random (Gen) <= Brick_Probability then
                  Grid (R, C) := Brick;
               end if;
            end if;
         end if;
      end Try_Place_Brick;
   begin
      Random_Prob.Reset (Gen);
      
      -- 1. Initialize all as Empty
      for R in 1 .. Max_Rows loop
         for C in 1 .. Max_Cols loop
            Grid (R, C) := Empty;
         end loop;
      end loop;
      
      -- 2. Place Unbreakable Walls (Boundary and Pillars)
      for R in 1 .. Max_Rows loop
         for C in 1 .. Max_Cols loop
            if R = 1 or R = Max_Rows or C = 1 or C = Max_Cols then
               Grid (R, C) := Wall;
            elsif R mod 2 = 1 and C mod 2 = 1 then
               Grid (R, C) := Wall;
            end if;
         end loop;
      end loop;

      -- 3. Pass through the maze row by row to spawn bricks near inner walls
      for R in 2 .. Max_Rows - 1 loop
         for C in 2 .. Max_Cols - 1 loop
            if Grid (R, C) = Wall then
               -- Generate destructible bricks orthogonally
               Try_Place_Brick (R - 1, C); -- Up
               Try_Place_Brick (R + 1, C); -- Down
               Try_Place_Brick (R, C - 1); -- Left
               Try_Place_Brick (R, C + 1); -- Right
            end if;
         end loop;
      end loop;
      
      -- Let's ensure top left corner (for player) is clear
      -- Typically (2, 2) is the start. (2, 3) and (3, 2) should also be clear.
      Grid (2, 2) := Empty;
      Grid (2, 3) := Empty;
      Grid (3, 2) := Empty;

   end Generate;

end Maze;
