with Terminal_Interface.Curses; use Terminal_Interface.Curses;
with Terminal_Interface.Curses_Constants;
with Maze;                      use Maze;
with Settings;                  use Settings;
with Ada.Exceptions;            use Ada.Exceptions;
with Ada.Text_IO;
with Ada.Calendar;              use Ada.Calendar;

with Game_State;                use Game_State;
with Game_UI;                   use Game_UI;
with Game_Logic;                use Game_Logic;

procedure Main is
   Ch : Key_Code;
begin
   Rand_Int.Reset (Gen);

   begin
      Init_Screen;
      Set_Echo_Mode (False);
      Set_CBreak_Mode (True);
      Set_KeyPad_Mode (Standard_Window, True);

      declare
         Vis : Cursor_Visibility := Invisible;
      begin
         Set_Cursor_Visibility (Vis);
      exception
         when others =>
            null;
      end;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           ("Failed to initialize screen: " & Exception_Message (E));
         return;
   end;

   if Has_Colors then
      begin
         Game_UI.Initialize_Colors;
      exception
         when others =>
            null;
      end;
   end if;

   Main_Loop :
   loop
      Quit_Requested := False;

      Game_UI.Draw_Splash;
      Set_Timeout_Mode (Standard_Window, Blocking, 0);
      Ch := Get_Keystroke (Standard_Window);
      if Ch = Character'Pos ('q') or else Ch = Character'Pos ('Q') then
         exit Main_Loop;
      end if;

      Game_UI.Show_Level_Selection;
      if Quit_Requested then
         exit Main_Loop;
      end if;

      Score := 0;
      Lives := Settings.Initial_Lives;
      Game_Logic.Reset_Level (New_Layout => True);

      Game_Loop :
      loop
         Set_Timeout_Mode (Standard_Window, Non_Blocking, 0);

         if Clock >= Next_Tick then
            Next_Tick := Next_Tick + 1.0;

            Mode_Timer := Mode_Timer + 1;
            if Mode_Timer >= Settings.Mode_Switch_Sec then
               Mode_Timer := 0;
               if Global_Balloon_Mode = Friendly then
                  Global_Balloon_Mode := Hostile;
               else
                  Global_Balloon_Mode := Friendly;
               end if;
            end if;

            for I in Bombs'Range loop
               if Bombs (I).Active and then (Bombs (I).Explosion_Tick = 0) then
                  Bombs (I).Timer := Bombs (I).Timer - 1;
                  if Bombs (I).Timer <= 0 then
                     Game_Logic.Explode_Bomb (I);
                  end if;
               end if;
            end loop;
         end if;

         for I in Bombs'Range loop
            if Bombs (I).Active and then (Bombs (I).Explosion_Tick > 0) then
               Bombs (I).Explosion_Tick := Bombs (I).Explosion_Tick - 1;
               if Bombs (I).Explosion_Tick <= 0 then
                  Bombs (I).Active := False;
                  if not Player_Dead then
                     Game_Logic.Check_Level_Cleared;
                  end if;
               else
                  Game_Logic.Check_Explosion_Damage (I);
               end if;
            end if;
         end loop;

         for I in Balloons'Range loop
            if Balloons (I).Active then
               if Balloons (I).Death_Tick > 0 then
                  Balloons (I).Death_Tick := Balloons (I).Death_Tick - 1;
                  if Balloons (I).Death_Tick <= 0 then
                     Balloons (I).Active := False;
                     if not Player_Dead then
                        Game_Logic.Check_Level_Cleared;
                     end if;
                  end if;
               end if;
            end if;
         end loop;

         if (Player_Dead and then (Player_Death_Tick > 0)) then
            Player_Death_Tick := Player_Death_Tick - 1;
            if Lives = 0 then
               Flush_Input;
            end if;
            if (Player_Death_Tick = 0 and then Lives > 0) then
               Game_Logic.Reset_Level (New_Layout => False);
            end if;
         end if;

         Balloon_Tick := Balloon_Tick + 1;
         if (Balloon_Tick >= Settings.Balloon_Move_Tick_Rate) then
            Balloon_Tick := 0;
            Game_Logic.Move_Balloons;
         end if;

         Game_UI.Draw_Frame;

         Ch := Get_Keystroke (Standard_Window);
         if Ch = Character'Pos ('q') or else Ch = Character'Pos ('Q') then
            exit Game_Loop;
         elsif Ch = Character'Pos ('r') or else Ch = Character'Pos ('R') then
            if (Player_Dead and then (Player_Death_Tick = 0)) then
               if (Lives = 0) then
                  exit Game_Loop;
               else
                  Game_Logic.Reset_Level (New_Layout => False);
               end if;
            elsif not Player_Dead then
               Game_Logic.Reset_Level (New_Layout => False);
            end if;
         elsif
           (Player_Dead and then (Player_Death_Tick = 0 and then Lives = 0))
         then
            if Ch = Character'Pos (' ') then
               exit Game_Loop;
            end if;
         elsif (not Player_Dead)
           and then (Ch /= Terminal_Interface.Curses_Constants.ERR)
         then
            if Ch = Character'Pos (' ') then
               for I in Bombs'Range loop
                  if not Bombs (I).Active then
                     declare
                        Exists : Boolean := False;
                     begin
                        for J in Bombs'Range loop
                           if Bombs (J).Active
                             and then (Bombs (J).Row = Player_Row)
                             and then (Bombs (J).Col = Player_Col)
                           then
                              Exists := True;
                           end if;
                        end loop;
                        if not Exists then
                           Bombs (I).Active         := True;
                           Bombs (I).Row            := Player_Row;
                           Bombs (I).Col            := Player_Col;
                           Bombs (I).Timer          := Settings.Bomb_Timer_Sec;
                           Bombs (I).Explosion_Tick := 0;
                        end if;
                     end;
                     exit;
                  end if;
               end loop;
            elsif Ch = Key_Cursor_Up or else Ch = Character'Pos ('w')
              or else Ch = Character'Pos ('W')
            then
               if Grid (Player_Row - 1, Player_Col) /= Maze.Wall
                 and then Grid (Player_Row - 1, Player_Col) /= Maze.Brick
               then
                  Player_Row := Player_Row - 1;
                  Game_Logic.Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Game_Logic.Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Down or else Ch = Character'Pos ('s')
              or else Ch = Character'Pos ('S')
            then
               if Grid (Player_Row + 1, Player_Col) /= Maze.Wall
                 and then Grid (Player_Row + 1, Player_Col) /= Maze.Brick
               then
                  Player_Row := Player_Row + 1;
                  Game_Logic.Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Game_Logic.Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Left or else Ch = Character'Pos ('a')
              or else Ch = Character'Pos ('A')
            then
               if Grid (Player_Row, Player_Col - 1) /= Maze.Wall
                 and then Grid (Player_Row, Player_Col - 1) /= Maze.Brick
               then
                  Player_Col := Player_Col - 1;
                  Game_Logic.Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Game_Logic.Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Right or else Ch = Character'Pos ('d')
              or else Ch = Character'Pos ('D')
            then
               if Grid (Player_Row, Player_Col + 1) /= Maze.Wall
                 and then Grid (Player_Row, Player_Col + 1) /= Maze.Brick
               then
                  Player_Col := Player_Col + 1;
                  Game_Logic.Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Game_Logic.Lose_Life;
                     end if;
                  end loop;
               end if;
            end if;
         end if;

         delay 0.05;
      end loop Game_Loop;

   end loop Main_Loop;

   End_Windows;
exception
   when E : others =>
      End_Windows;
      Ada.Text_IO.Put_Line
        ("Unexpected error in main loop: " & Exception_Name (E) & " - " &
         Exception_Message (E));
      raise;
end Main;
