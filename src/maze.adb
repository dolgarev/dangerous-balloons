with Ada.Numerics.Discrete_Random;

package body Maze is

   procedure Generate (Grid : out Grid_Type) is
      subtype Prob_Range is Integer range 1 .. 100;
      package Random_Prob is new Ada.Numerics.Discrete_Random (Prob_Range);
      Gen : Random_Prob.Generator;
      
      procedure Carve (R, C : Integer) is
         D : array (1 .. 4) of Integer := [1, 2, 3, 4];
      begin
         -- Shuffle directions
         for I in 1 .. 3 loop
            declare
               Swap_Idx : constant Integer := (abs(Random_Prob.Random(Gen)) mod (5 - I)) + I;
               Tmp : constant Integer := D(I);
            begin
               D(I) := D(Swap_Idx);
               D(Swap_Idx) := Tmp;
            end;
         end loop;
         
         for I in 1 .. 4 loop
            declare
               DR : Integer := 0;
               DC : Integer := 0;
            begin
               if D(I) = 1 then DR := -2;
               elsif D(I) = 2 then DR := 2;
               elsif D(I) = 3 then DC := -2;
               else DC := 2; end if;
               
               declare
                  NR : constant Integer := R + DR;
                  NC : constant Integer := C + DC;
               begin
                  if NR >= 2 and then NR <= Max_Rows - 1 and then NC >= 2 and then NC <= Max_Cols - 1 then
                     if Grid (NR, NC) = Brick then
                        Grid (NR, NC) := Empty;
                        Grid (R + DR / 2, C + DC / 2) := Empty;
                        Carve (NR, NC);
                     end if;
                  end if;
               end;
            end;
         end loop;
      end Carve;
      
   begin
      Random_Prob.Reset (Gen);
      
      -- 1. Initialize Border and Inner Grid
      for R in 1 .. Max_Rows loop
         for C in 1 .. Max_Cols loop
            if R = 1 or else R = Max_Rows or else C = 1 or else C = Max_Cols then
               Grid (R, C) := Wall;
            elsif R mod 2 = 1 and then C mod 2 = 1 then
               Grid (R, C) := Wall;
            else
               Grid (R, C) := Brick;
            end if;
         end loop;
      end loop;
      
      -- 2. Carve Perfect Maze
      Grid (2, 2) := Empty;
      Carve (2, 2);
      
      -- 3. Randomize Remaining Bricks based on probability to create loops
      for R in 2 .. Max_Rows - 1 loop
         for C in 2 .. Max_Cols - 1 loop
            if Grid (R, C) = Brick then
               if Random_Prob.Random (Gen) > Settings.Brick_Probability then
                  Grid (R, C) := Empty;
               end if;
            end if;
         end loop;
      end loop;
      
      -- 4. Ensure top left corner is clear for the player
      Grid (2, 2) := Empty;
      Grid (2, 3) := Empty;
      Grid (3, 2) := Empty;

   end Generate;

end Maze;
