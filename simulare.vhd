library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simulare_temperatura is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        oraCurenta_in   : in  STD_LOGIC_VECTOR(5 downto 0);
        tempMax_reg_in  : in  STD_LOGIC_VECTOR(149 downto 0);
        oraMax_reg_in   : in  STD_LOGIC_VECTOR(143 downto 0);
        sw              : in  STD_LOGIC_VECTOR(15 downto 0);
        seg             : out STD_LOGIC_VECTOR(6 downto 0);
        tempMin_in      : in  integer range 0 to 31;
        an              : out STD_LOGIC_VECTOR(7 downto 0)
    );
end simulare_temperatura;

architecture Behavioral of simulare_temperatura is

    -- Control simulare
    signal index_gasit         : integer range -1 to 23 := -1;
    signal temp_la_index       : integer range 0 to 31 := 0;
    signal temperatura_actuala : integer range 0 to 31 := 20;
    signal start_simulare      : boolean := false;

    -- Ceas
    signal ora                 : integer range 0 to 23 := 0;
    signal minut               : integer range 0 to 59 := 0;
    signal secunda_counter     : unsigned(26 downto 0) := (others => '0');  -- 1 sec @ 100 MHz

    -- Afi?aj
    signal cifre : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal cifra0, cifra1, cifra2, cifra3 : STD_LOGIC_VECTOR(3 downto 0);
    signal cifra4, cifra5, cifra6, cifra7 : STD_LOGIC_VECTOR(3 downto 0);
    signal active_digit                   : integer range 0 to 7 := 0;
    signal refresh_counter                : unsigned(19 downto 0) := (others => '0');

    signal counter_temp                   : unsigned(27 downto 0) := (others => '0'); -- 3 sec

    signal enable_simulation              : STD_LOGIC := '0';

begin

    -- Activare simulare
    enable_simulation <= '1' when (sw(12) = '1' and sw(13) = '0') else '0';

    -- Ini?ializare ?i incrementare orã
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ora <= to_integer(unsigned(oraCurenta_in));
                minut <= 0;
                secunda_counter <= (others => '0');
            else
                secunda_counter <= secunda_counter + 1;
                if secunda_counter = 100_000_000 then  -- 1 sec
                    secunda_counter <= (others => '0');
                    if minut = 59 then
                        minut <= 0;
                        if ora = 23 then
                            ora <= 0;
                        else
                            ora <= ora + 1;
                        end if;
                    else
                        minut <= minut + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Simulare temperaturã
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                temperatura_actuala <= 20;
                counter_temp        <= (others => '0');
                start_simulare      <= false;
                temp_la_index       <= 0;
                index_gasit         <= -1;

            elsif enable_simulation = '1' then
                if index_gasit = -1 then
                    for i in 0 to 23 loop
                        if to_integer(unsigned(oraMax_reg_in(i*6 + 5 downto i*6))) = to_integer(unsigned(oraCurenta_in)) then
                            index_gasit <= i;
                            exit;
                        end if;
                    end loop;

                elsif not start_simulare then
                    temp_la_index       <= to_integer(unsigned(tempMax_reg_in(index_gasit*5 + 4 downto index_gasit*5)));
                    temperatura_actuala <= 20;
                    start_simulare      <= true;
                    counter_temp        <= (others => '0');

                else
                    counter_temp <= counter_temp + 1;
                    if counter_temp = 300_000_000 then -- 3 sec
                        if temperatura_actuala < temp_la_index then
                            temperatura_actuala <= temperatura_actuala + 1;
                        elsif temperatura_actuala > tempMin_in then
                            temperatura_actuala <= temperatura_actuala - 1;
                        end if;
                        counter_temp <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Actualizare cifre pentru afi?aj
    process(clk)
    begin
        if rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
            if refresh_counter(13 downto 0) = 0 then
                active_digit <= (active_digit + 1) mod 8;
            end if;

            -- HHMM
            cifra3 <= std_logic_vector(to_unsigned(ora / 10, 4));
            cifra2 <= std_logic_vector(to_unsigned(ora mod 10, 4));
            cifra1 <= std_logic_vector(to_unsigned(minut / 10, 4));
            cifra0 <= std_logic_vector(to_unsigned(minut mod 10, 4));

            -- Temperatura actualã
            cifra5 <= std_logic_vector(to_unsigned(temperatura_actuala / 10, 4));
            cifra4 <= std_logic_vector(to_unsigned(temperatura_actuala mod 10, 4));

            -- Cifre nefolosite
            cifra6 <= "1111";
            cifra7 <= "1111";
        end if;
    end process;

    -- Multiplexare ?i codificare 7-segmente
    process(active_digit)
    begin
        case active_digit is
            when 0 => an <= "11111110"; cifre <= cifra0;
            when 1 => an <= "11111101"; cifre <= cifra1;
            when 2 => an <= "11111011"; cifre <= cifra2;
            when 3 => an <= "11110111"; cifre <= cifra3;
            when 4 => an <= "11101111"; cifre <= cifra4;
            when 5 => an <= "11011111"; cifre <= cifra5;
            when 6 => an <= "10111111"; cifre <= cifra6;
            when 7 => an <= "01111111"; cifre <= cifra7;
            when others => an <= "11111111"; cifre <= "1111";
        end case;

        case cifre is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when "1000" => seg <= "0000000"; -- 8
            when "1001" => seg <= "0010000"; -- 9
            when others => seg <= "1111111"; -- blank
        end case;
    end process;

end Behavioral;