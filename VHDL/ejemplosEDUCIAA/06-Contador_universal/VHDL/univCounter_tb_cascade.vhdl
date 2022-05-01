--------------------------------------------------------------------------------
--- Entidad: univCounter_tb_cascade.
--- Descripción: Esta entidad es un testbench que permite verificar el
--               funcionamiento de un contador binario universal de 2 bits y
--               módulo 4 compuesto internamente por 2 contadores de 1 bit y
--               módulo 2 de entidad univCounter. El contador total o top-level
--               se activa por flanco ascendente de clock, tiene entradas
--               sincrónicas de habilitación de conteo, habilitación y datos
--               para carga paralela, configuración de sentido de cuenta y posee
--               una línea asincrónica de habilitación de salida y otra de
--               reset. El contador cuenta los pulsos en su entrada de clock, la
--               cual se pone en 10 MHz para esta prueba.
--- Propósito: Este testbench prueba de forma bastante completa al contador,
--             considerando situaciones de importancia que permiten verificar
--             su correcto funcionamiento. Estas situaciones son: conteo
--             ascendente y descendente, secuencia de cuenta completa, reseteo,
--             verificación del correcto funcionamiento de la salida
--             "terminalCount_out", carga paralela y conteo a partir de allí,
--             pausa de la cuenta que también afecta al estado de
--             "terminalCount_out", habilitación de la salida y jerarquía de las
--             entradas.
--- Autor: Federico Alejandro Vazquez Saraullo.
--- Ultima revisión: 11/01/2021.
--- Dependencias: Paquetes std_logic_1164.all y ieee.numeric_std.all de la
--                biblioteca estándar ieee.
--------------------------------------------------------------------------------
--Inclusión de paquetes.
library ieee;                 --Biblioteca estándar ieee.
use ieee.std_logic_1164.all;  --Paquete para std_logic y std_logic_vector.
use ieee.numeric_std.all;     --Paquete para unsigned y signed.

--Entidad del testbench.
entity univCounter_tb_cascade is
end entity univCounter_tb_cascade;

--Arquitectura del testbench.
architecture univCounter_tb_cascade_arch of univCounter_tb_cascade is
    --Declaración del contador a probar.
    component univCounter is
        generic (
            nBits           : integer := 8;
            modulus         : integer := 256;
            risingEdgeClock : BOOLEAN := TRUE
        );
        port (
            d_in              : in  std_logic_vector(nBits-1 downto 0);
            clock_in          : in  std_logic;
            outEnable_in      : in  std_logic;
            reset_in          : in  std_logic;
            counterEnable_in  : in  std_logic;
            load_in           : in  std_logic;
            countUp_in        : in  std_logic;
            q_out             : out std_logic_vector(nBits-1 downto 0);
            terminalCount_out : out std_logic
        );
    end component;

    --Declaración de constantes.
    constant TESTED_NBITS_EACH_COUNTER   : integer := 1;
    constant TESTED_MODULUS_EACH_COUNTER : integer := 2;
    constant TESTED_NBITS                : integer := 2;
    constant TESTED_MODULUS              : integer := 4;
    constant PERIOD                      : time    := 100 ns;

    --Declaración de estímulos y señales de monitoreo.
    --Entradas al contador completo.
    signal test_d_cnt_s         : std_logic_vector(TESTED_NBITS-1 downto 0);
    signal test_clock_s         : std_logic;
    signal test_outEnable_s     : std_logic;
    signal test_reset_s         : std_logic;
    signal test_counterEnable_s	: std_logic;
    signal test_load_s          : std_logic;
    signal test_countUp_s      	: std_logic;

    --Salidas al contador completo.
    signal test_q_cnt_s         : std_logic_vector(TESTED_NBITS-1 downto 0);
    signal test_terminalCount_s : std_logic;

    --Declaración de señales para interconexiones entre contadores internos.
    signal test_interTerminalCount0_s : std_logic;
    signal test_interTerminalCount1_s : std_logic;
    signal test_interCounterEnable1_s : std_logic;

    --Señal auxiliar para detener la simulación (por defecto es FALSE).
    signal stopSimulation_s : BOOLEAN := FALSE;

    --Declaración de una constante como estímulo de entrada para precargar el
    --contador completo en tres.
    constant DATA_IN_COUNTER : std_logic_vector := "11";

begin
    --Instanciación de los contadores internos.
    univCounter_0 : univCounter
        generic map ( nBits           => TESTED_NBITS_EACH_COUNTER,
                      modulus         => TESTED_MODULUS_EACH_COUNTER,
                      risingEdgeClock => TRUE)
        port map ( d_in              => test_d_cnt_s(TESTED_NBITS-2 downto TESTED_NBITS-2),
                   clock_in          => test_clock_s,
                   outEnable_in      => test_outEnable_s,
                   reset_in          => test_reset_s,
                   counterEnable_in  => test_counterEnable_s,
                   load_in           => test_load_s,
                   countUp_in        => test_countUp_s,
                   q_out             => test_q_cnt_s(TESTED_NBITS-2 downto TESTED_NBITS-2),
                   terminalCount_out => test_interTerminalCount0_s);

    univCounter_1 : univCounter
        generic map ( nBits           => TESTED_NBITS_EACH_COUNTER,
                      modulus         => TESTED_MODULUS_EACH_COUNTER,
                      risingEdgeClock => TRUE)
        port map ( d_in              => test_d_cnt_s(TESTED_NBITS-1 downto TESTED_NBITS-1),
                   clock_in          => test_clock_s,
                   outEnable_in      => test_outEnable_s,
                   reset_in          => test_reset_s,
                   counterEnable_in  => test_interCounterEnable1_s,
                   load_in           => test_load_s,
                   countUp_in        => test_countUp_s,
                   q_out             => test_q_cnt_s(TESTED_NBITS-1 downto TESTED_NBITS-1),
                   terminalCount_out => test_interTerminalCount1_s);
    --Proceso de generación de clock.
    clockGeneration : process
    begin
        test_clock_s <= '1';
        wait for PERIOD/2;
        test_clock_s <= '0';
        wait for PERIOD/2;
        if (stopSimulation_s = TRUE) then
            wait;
        end if;
    end process clockGeneration;

    --Proceso de aplicación de estímulos.
    applyStimulus : process
    begin
        --Estado inicial: dato de entrada en 3 ("11"), carga paralela
        --deshabilitada, conteo ascendente y contador y salida habilitados.
        test_load_s          <= '0';
        test_d_cnt_s         <= DATA_IN_COUNTER;
        test_countUp_s       <= '1';
        test_outEnable_s     <= '1';
        test_counterEnable_s <= '1';
        stopSimulation_s     <= FALSE;

        --Reset inicial que dura dos periodos y medio de clock. Se agrega el
        --medio período como desfasaje temporal inicial.
        test_reset_s <= '1';
        wait for (2.5)*PERIOD;
        test_reset_s <= '0';

        --Se cuenta ascendentemente un ciclo completo hasta reiniciarse en 0. Se
        --verifica que "test_terminalCount_s" se pone en alto.
        wait for PERIOD*(TESTED_MODULUS + 1);

        --Se carga el contador con el valor DATA_IN_COUNTER y luego se cuenta
        --regresivamente hasta que de 0 pasa al (módulo - 1). Cuanto está en 0
        --se deshabilita el contador por un período. Así se verifica que la
        --"test_terminalCount_s" se pone en alto y solo cuando el contador
        --está habilitado. Se verifica también la pausa de la cuenta.
        test_load_s    <= '1';
        test_countUp_s <= '0';
        wait for PERIOD;
        test_load_s    <= '0';

        wait for PERIOD * to_integer(unsigned(DATA_IN_COUNTER));

        test_counterEnable_s <= '0';
        wait for PERIOD;
        test_counterEnable_s <= '1';
        wait for PERIOD*2;

        --Se pretende cargar el contador cuando este está deshabilitado, lo cual
        --no se permite.
        test_counterEnable_s <= '0';
        test_load_s          <= '1';
        wait for PERIOD;

        --Con la carga paralela habilitada y el contador deshabilitado, se hace
        --un reset para poner la salida y la cuenta interna en cero. Esto
        --permite verificar la asincrónía y mayor jerarquía de la entrada de
        --reset. Se deja pasar un período y luego se desactiva el reset y la
        --carga paralela y también se vuelve a habilitar el contador en conteo
        --descendente.
        test_reset_s         <= '1';
        wait for PERIOD;
        test_reset_s         <= '0';
        test_load_s          <= '0';
        test_counterEnable_s <= '1';

        --Se cambia el conteo a ascendente y se cuentan algunos pulsos para ver
        --que funcione correctamente.
        test_countUp_s <= '1';
        wait for PERIOD*4;

        --Se deshabilita la salida del contador y se dejan pasar algunos pulsos
        --de clock. Aquí se prueba la asincronía y más alta jerarquía de la
        --entrada de habilitación de la salida, y que el contador sigue
        --trabajando internamente.
        test_outEnable_s <= '0';
        wait for PERIOD*4;

        --Se detiene la simulación.
        stopSimulation_s <= TRUE;
        wait;
    end process applyStimulus;

    --Interconexiones entre contadores internos.
    test_interCounterEnable1_s <= test_interTerminalCount0_s or
                                  (test_load_s and test_counterEnable_s);

    test_terminalCount_s <= test_interTerminalCount0_s and
                            test_interTerminalCount1_s;
end architecture univCounter_tb_cascade_arch;