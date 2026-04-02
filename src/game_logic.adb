with Settings;  use Settings;
with Maze;      use Maze;
with Game_State; use Game_State;
with Ada.Calendar; use Ada.Calendar;

package body Game_Logic is

   procedure Spawn_Balloons is
      Placed    : Integer          := 0;
      R, C_Idx  : Integer;
      Max_Spawn : constant Integer :=
        (Settings.Initial_Balloons - 1) + Current_Level;
   begin
      for I in Balloons'Range loop
         Balloons (I).Active     := False;
         Balloons (I).Death_Tick := 0;
      end loop;

      while (Placed < Max_Spawn) and then (Placed < Balloons'Last) loop
         R     := (abs (Rand_Int.Random (Gen)) mod Maze.Max_Rows) + 1;
         C_Idx := (abs (Rand_Int.Random (Gen)) mod Maze.Max_Cols) + 1;
         if Grid (R, C_Idx) = Maze.Empty and then ((R > 4) or (C_Idx > 4)) then
            Placed                   := Placed + 1;
            Balloons (Placed).Active := True;
            Balloons (Placed).Row    := R;
            Balloons (Placed).Col    := C_Idx;
            Balloons (Placed).Dir_R  := 0;
            Balloons (Placed).Dir_C  := 0;
         end if;
      end loop;
   end Spawn_Balloons;

   procedure Reset_Level (New_Layout : Boolean := True) is
   begin
      Player_Dead       := False;
      Player_Death_Tick := 0;

      if New_Layout then
         Maze.Generate (Grid);
         Spawn_Balloons;
         Level_Backup   := Grid;
         Balloon_Backup := Balloons;
      else
         Grid     := Level_Backup;
         Balloons := Balloon_Backup;
      end if;

      Player_Row := 2;
      Player_Col := 2;
      for I in Bombs'Range loop
         Bombs (I).Active         := False;
         Bombs (I).Explosion_Tick := 0;
      end loop;
      Global_Balloon_Mode := Friendly;
      Mode_Timer          := 0;
      Next_Tick           := Clock + 0.1;
   end Reset_Level;

   procedure Lose_Life is
   begin
      if not Player_Dead then
         Player_Dead       := True;
         Player_Death_Tick := Player_Death_Ticks;
         if (Lives > 0) then
            Lives := Lives - 1;
         end if;
      end if;
   end Lose_Life;

   procedure Check_Explosion_Damage (B_Idx : Integer) is
      BR : constant Integer := Bombs (B_Idx).Row;
      BC : constant Integer := Bombs (B_Idx).Col;
   begin
      for DR in Integer range -1 .. 1 loop
         for DC in Integer range -1 .. 1 loop
            if abs (DR) + abs (DC) <= 1 then
               declare
                  TR : constant Integer := BR + DR;
                  TC : constant Integer := BC + DC;
               begin
                  if (TR in 1 .. Maze.Max_Rows)
                    and then (TC in 1 .. Maze.Max_Cols)
                  then
                     if Grid (TR, TC) /= Wall then
                        if (Player_Row = TR) and then (Player_Col = TC)
                          and then (not Player_Dead)
                        then
                           Lose_Life;
                        end if;

                        for J in Balloons'Range loop
                           if Balloons (J).Active
                             and then (Balloons (J).Death_Tick = 0)
                             and then (Balloons (J).Row = TR)
                             and then (Balloons (J).Col = TC)
                           then
                              Balloons (J).Death_Tick :=
                                Settings.Balloon_Death_Ticks;
                              if Global_Balloon_Mode = Friendly then
                                 Score := Score + Score_Balloon_F;
                              else
                                 Score := Score + Score_Balloon_H;
                              end if;
                           end if;
                        end loop;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Check_Explosion_Damage;

   procedure Explode_Bomb (B_Idx : Integer) is
      BR : constant Integer := Bombs (B_Idx).Row;
      BC : constant Integer := Bombs (B_Idx).Col;
   begin
      Bombs (B_Idx).Explosion_Tick := Explosion_Duration_Ticks;
      for DR in Integer range -1 .. 1 loop
         for DC in Integer range -1 .. 1 loop
            if abs (DR) + abs (DC) <= 1 then
               declare
                  TR : constant Integer := BR + DR;
                  TC : constant Integer := BC + DC;
               begin
                  if (TR in 1 .. Maze.Max_Rows)
                    and then (TC in 1 .. Maze.Max_Cols)
                  then
                     if Grid (TR, TC) = Brick then
                        Score := Score + Score_Brick;
                        declare
                           Roll : constant Integer :=
                             (abs (Rand_Int.Random (Gen)) mod 100) + 1;
                        begin
                           if Roll <= Settings.Item_Appear_Prob then
                              declare
                                 Item_Roll : constant Integer :=
                                   (abs (Rand_Int.Random (Gen)) mod 100) + 1;
                              begin
                                 if Item_Roll <= Settings.Item_Life_Prob then
                                    Grid (TR, TC) := Item_Life;
                                 elsif Item_Roll <=
                                   Settings.Item_Life_Prob +
                                     Settings.Item_Score_Prob
                                 then
                                    Grid (TR, TC) := Item_Score;
                                 else
                                    Grid (TR, TC) := Door;
                                 end if;
                              end;
                           else
                              Grid (TR, TC) := Empty;
                           end if;
                        end;
                     elsif Grid (TR, TC) = Item_Life
                       or else Grid (TR, TC) = Item_Score
                     then
                        Grid (TR, TC) := Empty;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      Check_Explosion_Damage (B_Idx);
   end Explode_Bomb;

   procedure Move_Balloons is
      function Try_Move_Towards (B : in out Balloon_Rec) return Boolean is
         DR : Integer := 0;
         DC : Integer := 0;
      begin
         if Player_Dead then
            return False;
         end if;

         if Player_Row < B.Row then
            DR := -1;
         elsif Player_Row > B.Row then
            DR := 1;
         end if;

         if DR /= 0
           and then
           (Grid (B.Row + DR, B.Col) = Maze.Empty or
            Grid (B.Row + DR, B.Col) = Maze.Item_Life or
            Grid (B.Row + DR, B.Col) = Maze.Item_Score)
         then
            B.Row := B.Row + DR;
            return True;
         end if;

         if Player_Col < B.Col then
            DC := -1;
         elsif Player_Col > B.Col then
            DC := 1;
         end if;

         if DC /= 0
           and then
           (Grid (B.Row, B.Col + DC) = Maze.Empty or
            Grid (B.Row, B.Col + DC) = Maze.Item_Life or
            Grid (B.Row, B.Col + DC) = Maze.Item_Score)
         then
            B.Col := B.Col + DC;
            return True;
         end if;

         return False;
      end Try_Move_Towards;

      procedure Random_Move (B : in out Balloon_Rec) is
         Try_Dir : Integer;
      begin
         Try_Dir := (abs (Rand_Int.Random (Gen)) mod 4);

         if B.Dir_R /= 0 or B.Dir_C /= 0 then
            if Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Empty or
              Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Item_Life or
              Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Item_Score
            then
               if Rand_Int.Random (Gen) < 70 then
                  B.Row := B.Row + B.Dir_R;
                  B.Col := B.Col + B.Dir_C;
                  return;
               end if;
            end if;
         end if;

         for I in 1 .. 4 loop
            declare
               D  : constant Integer := (Try_Dir + I) mod 4;
               TR : Integer          := B.Row;
               TC : Integer          := B.Col;
            begin
               if D = 0 then
                  TR := TR - 1;
               elsif D = 1 then
                  TR := TR + 1;
               elsif D = 2 then
                  TC := TC - 1;
               else
                  TC := TC + 1;
               end if;

               if Grid (TR, TC) = Maze.Empty or
                 Grid (TR, TC) = Maze.Item_Life or
                 Grid (TR, TC) = Maze.Item_Score
               then
                  B.Dir_R := TR - B.Row;
                  B.Dir_C := TC - B.Col;
                  B.Row   := TR;
                  B.Col   := TC;
                  return;
               end if;
            end;
         end loop;
      end Random_Move;

      procedure Handle_Balloon_Collision (R, C : Integer) is
      begin
         if Grid (R, C) = Maze.Item_Score then
            if Score > Settings.Score_Bonus_Points then
               Score := Score - Settings.Score_Bonus_Points;
            else
               Score := 0;
            end if;
         end if;
         if Grid (R, C) = Maze.Item_Life or Grid (R, C) = Maze.Item_Score then
            Grid (R, C) := Maze.Empty;
         end if;
      end Handle_Balloon_Collision;

   begin
      for I in Balloons'Range loop
         if Balloons (I).Active and then (Balloons (I).Death_Tick = 0) then
            if Global_Balloon_Mode = Hostile then
               if not Try_Move_Towards (Balloons (I)) then
                  Random_Move (Balloons (I));
               end if;
            else
               Random_Move (Balloons (I));
            end if;

            Handle_Balloon_Collision (Balloons (I).Row, Balloons (I).Col);

            if (Balloons (I).Row = Player_Row)
              and then (Balloons (I).Col = Player_Col)
              and then (not Player_Dead)
            then
               Lose_Life;
            end if;
         end if;
      end loop;
   end Move_Balloons;

   procedure Check_Level_Cleared is
      Any_Active : Boolean := False;
   begin
      if Player_Dead then
         return;
      end if;

      for I in Balloons'Range loop
         if Balloons (I).Active then
            Any_Active := True;
            exit;
         end if;
      end loop;

      if not Any_Active then
         Current_Level := Current_Level + 1;
         if Current_Level > Settings.Max_Levels then
            Current_Level := 1;
         end if;
         Reset_Level (New_Layout => True);
      end if;
   end Check_Level_Cleared;

   procedure Handle_Player_Collision is
   begin
      case Grid (Player_Row, Player_Col) is
         when Maze.Item_Life =>
            if Lives < Settings.Max_Lives_Limit then
               Lives := Lives + 1;
            else
               Score := Score + Settings.Score_Extra_Life;
            end if;
            Grid (Player_Row, Player_Col) := Maze.Empty;
         when Maze.Item_Score =>
            Score := Score + Settings.Score_Bonus_Points;
            Grid (Player_Row, Player_Col) := Maze.Empty;
         when Maze.Door =>
            Current_Level := Current_Level + 1;
            if Current_Level > Settings.Max_Levels then
               Current_Level := 1;
            end if;
            Reset_Level (New_Layout => True);
         when others =>
            null;
      end case;
   end Handle_Player_Collision;

end Game_Logic;
