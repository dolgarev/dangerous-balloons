with Maze;
with Settings;
with Ada.Calendar;
with Ada.Numerics.Discrete_Random;

package Game_State is
   
   Grid         : Maze.Grid_Type;
   Level_Backup : Maze.Grid_Type;

   Player_Row        : Integer := 2;
   Player_Col        : Integer := 2;
   Player_Dead       : Boolean := False;
   Player_Death_Tick : Integer := 0;

   Score         : Integer := 0;
   Current_Level : Integer := Settings.Initial_Level;
   Lives         : Integer := Settings.Initial_Lives;

   type Bomb_Rec is record
      Active         : Boolean := False;
      Row            : Integer := 0;
      Col            : Integer := 0;
      Timer          : Integer := 0;
      Explosion_Tick : Integer := 0;
   end record;
   Bombs : array (1 .. Settings.Max_Bombs) of Bomb_Rec;

   type Balloon_Mode is (Friendly, Hostile);
   type Balloon_Rec is record
      Active     : Boolean := False;
      Row        : Integer := 0;
      Col        : Integer := 0;
      Dir_R      : Integer := 0;
      Dir_C      : Integer := 0;
      Death_Tick : Integer := 0;
   end record;

   type Balloon_Array is array (1 .. Settings.Max_Balloons) of Balloon_Rec;
   Balloons       : Balloon_Array;
   Balloon_Backup : Balloon_Array;

   Global_Balloon_Mode : Balloon_Mode := Friendly;
   Mode_Timer          : Integer      := 0;
   Balloon_Tick        : Integer      := 0;

   Next_Tick : Ada.Calendar.Time;

   subtype Rand_Range is Integer range 1 .. 100;
   package Rand_Int is new Ada.Numerics.Discrete_Random (Rand_Range);
   Gen : Rand_Int.Generator;

   Quit_Requested : Boolean := False;

end Game_State;
