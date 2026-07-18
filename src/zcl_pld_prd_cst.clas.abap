CLASS zcl_pld_prd_cst DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.

    METHODS get_pdf_64
      IMPORTING
        VALUE(io_orderid) TYPE i_manufacturingorder-manufacturingorder
      RETURNING
        VALUE(pdf_64)     TYPE string.

    CLASS-METHODS sanitize_text
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS escape_xml
      IMPORTING
        iv_in         TYPE any
      RETURNING
        VALUE(rv_out) TYPE string.


  PRIVATE SECTION.

    METHODS build_xml
      IMPORTING
        VALUE(io_orderid) TYPE i_manufacturingorder-manufacturingorder
      RETURNING
        VALUE(rv_xml)     TYPE string.

ENDCLASS.



CLASS ZCL_PLD_PRD_CST IMPLEMENTATION.


  METHOD get_pdf_64.

    DATA(lv_xml) = build_xml(
                      io_orderid = io_orderid ).

    CALL METHOD zadobe_call=>getpdf
      EXPORTING
        template = 'ZPP_PLD_PC/ZPP_PLD_PC'
        xmldata  = lv_xml
      RECEIVING
        result   = DATA(lv_result).

    IF lv_result IS NOT INITIAL.
      pdf_64 = lv_result.
    ENDIF.

  ENDMETHOD.


  METHOD build_xml.

    DATA : lv_processorder TYPE  i_manufacturingorder-manufacturingorder,
           lv_cust         TYPE i_customer-customer,
           lv_orderdate    TYPE  string.

    lv_processorder = |{ io_orderid ALPHA = OUT }|.

    DATA(lv_d) = cl_abap_context_info=>get_system_date( ).

    SELECT SINGLE fiscalyear
      FROM i_fiscalyearperiod
      WHERE fiscalyearvariant = 'V3'
        AND fiscalperiodstartdate <= @lv_d
        AND fiscalperiodenddate   >= @lv_d
      INTO @DATA(lv_fiscper).

    DATA(lv_from) = |{ lv_fiscper }001|.
    DATA(lv_to)   = |{ lv_fiscper }012|.

    DATA : lv_rm_cost     TYPE p LENGTH 16 DECIMALS 2,
           lv_overhead    TYPE p LENGTH 16 DECIMALS 2,
           lv_fixed_oh    TYPE p LENGTH 16 DECIMALS 2,
           lv_variable_oh TYPE p LENGTH 16 DECIMALS 2,
           lv_prod_cost   TYPE p LENGTH 16 DECIMALS 2,
           lv_profit      TYPE p LENGTH 16 DECIMALS 2,
           lv_gpr         TYPE p LENGTH 5 DECIMALS 2.


    SELECT *
      FROM i_mfgorderactlplantgtldgrcost(
            p_ledger               = '0L',
            p_currencyrole         = '10',
            p_targetcostvariant    = '001',
            p_fromfiscalyearperiod = @lv_from,
            p_tofiscalyearperiod   = @lv_to
      )
      WHERE orderid = @io_orderid
      AND curplanprojslsordvalnstrategy <> '3'
      INTO TABLE @DATA(lt_cost).

    IF lt_cost IS INITIAL.
      RETURN. " or handle gracefully
    ENDIF.

    READ TABLE lt_cost INTO DATA(ls_first) INDEX 1.

    DATA: lv_header_mat_desc TYPE string.

    SELECT SINGLE productdescription
      FROM i_productdescription
      WHERE product = @ls_first-producedproduct
      INTO @lv_header_mat_desc.

    SELECT a~material,
      a~requiredquantity,
      a~externalprocessingprice,
      b~productdescription
    FROM i_processordercomponenttp AS a
    LEFT OUTER JOIN i_productdescription AS b
    ON a~material = b~product
    WHERE a~processorder = @io_orderid
    INTO TABLE @DATA(lt_poc).

    SELECT SINGLE *
    FROM zi_pld_prd_cst
      WHERE orderid = @io_orderid
      INTO @DATA(wa_orderid).

    lv_cust = |{ wa_orderid-customer ALPHA = IN }|.

    SELECT SINGLE
    customername
    FROM i_customer
    WHERE customer = @lv_cust
    INTO @DATA(lv_customer).

    IF wa_orderid-creationdate IS NOT INITIAL.
      lv_orderdate = |{ wa_orderid-creationdate+6(2) }.{ wa_orderid-creationdate+4(2) }.{ wa_orderid-creationdate+0(4) }|.
    ENDIF.

    LOOP AT lt_cost INTO DATA(ls_cost).

      IF ls_cost-glaccount CP '00004*'.

        lv_rm_cost += ls_cost-debitplancostindspcrcy.
      ENDIF.

      IF ls_cost-glaccount CP '00009*'.

        lv_overhead += ls_cost-debitplancostindspcrcy.

        IF ls_cost-partnercostctractivitytype = 'ZFOH' OR
           ls_cost-partnercostctractivitytype = 'ZFOMDR'.
          lv_fixed_oh += ls_cost-debitplancostindspcrcy.
        ENDIF.

        IF ls_cost-partnercostctractivitytype = 'ZAUX'
        OR ls_cost-partnercostctractivitytype = 'ZPOW'
        OR ls_cost-partnercostctractivitytype = 'ZLAB'.
          lv_variable_oh += ls_cost-debitplancostindspcrcy.
        ENDIF.

      ENDIF.

    ENDLOOP.

    " Production Cost
    lv_prod_cost = lv_rm_cost + lv_overhead.

    " Profit
    DATA : lv_sales TYPE p LENGTH 16 DECIMALS 2.
    DATA : lv_freight TYPE p LENGTH 16 DECIMALS 2.


    lv_sales = wa_orderid-salesunitprice.
    lv_freight = wa_orderid-freight.


    lv_profit = lv_sales - lv_freight - lv_prod_cost.

    IF lv_sales IS NOT INITIAL.
      lv_gpr = ( lv_profit / lv_sales ) * 100.
    ENDIF.

    DATA(lv_tot_oh) = |{ lv_overhead } ({ lv_variable_oh } (Variable) + { lv_fixed_oh } (Fixed) )|.

    DATA(lv_header) =
    |<form1>| &&
    |  <Design>| &&
    |    <plant>{ zcl_escape_xml=>escape_xml( ls_first-plantname ) }</plant>| &&
    |    <po>{ lv_processorder }</po>| &&
    |    <orderdate>{ lv_orderdate }</orderdate>| &&
    |    <material>{ zcl_escape_xml=>escape_xml( lv_header_mat_desc ) }</material>| &&
    |    <customer>{ zcl_escape_xml=>escape_xml( lv_customer ) }</customer>| &&
    |    <sup>{ wa_orderid-salesunitprice }</sup>| &&
    |    <freight>{ wa_orderid-freight }</freight>| &&
    |    <rcost>{ lv_rm_cost  }</rcost>| &&
    |    <obveerhead>{ zcl_escape_xml=>escape_xml( lv_tot_oh )  }</obveerhead>| &&
    |    <productionorder>{ lv_prod_cost }</productionorder>| &&
    |    <profit>{ lv_profit }</profit>| &&
    |    <GPR>{ lv_gpr DECIMALS = 2 }%</GPR>| &&
    |    <Table1>| &&
    |      <HeaderRow/>|.

    DATA(lv_items) = ``.
    DATA(lv_index) = 0.

    LOOP AT lt_poc INTO DATA(ls_item).

      lv_index += 1.

      DATA : lv_amt TYPE p LENGTH 16 DECIMALS 2.
      IF ls_item-requiredquantity > 0.
        lv_amt = ls_item-externalprocessingprice * ls_item-requiredquantity.
      ENDIF.


      " Append XML row
      lv_items = lv_items &&                            "#EC CI_NOORDER
      |      <Row1>| &&
      |        <sr>{ lv_index }</sr>| &&
      |        <mterial>{ zcl_escape_xml=>escape_xml( ls_item-material ) }</mterial>| &&
      |        <materiqltext>{ zcl_escape_xml=>escape_xml( ls_item-productdescription ) }</materiqltext>| &&
      |        <aty>{ ls_item-requiredquantity }</aty>| &&
      |        <rate>{ ls_item-externalprocessingprice }</rate>| &&
      |        <amnt>{ lv_amt }</amnt>| &&
      |      </Row1>|.

    ENDLOOP.

    DATA(lv_footer) =
    |    </Table1>| &&
    |  </Design>| &&
    |</form1>|.

    rv_xml = |{ lv_header }{ lv_items }{ lv_footer }|.

  ENDMETHOD.


  METHOD sanitize_text.

    CONSTANTS c_nbsp TYPE string VALUE ' '.  " ← NBSP pasted here

    rv_text = iv_text.

    REPLACE ALL OCCURRENCES OF c_nbsp IN rv_text WITH space.

    rv_text = escape(
                val    = rv_text
                format = cl_abap_format=>e_xml_text ).

    REPLACE ALL OCCURRENCES OF '&#160;' IN rv_text WITH space.

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
      IN rv_text WITH space.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
      IN rv_text WITH space.

    CONDENSE rv_text.

  ENDMETHOD.


  METHOD escape_xml.

    rv_out = |{ iv_in }|.   " explicit conversion to STRING

    IF rv_out IS INITIAL.
      RETURN.
    ENDIF.

    " Replace must be done in order to avoid double-escaping
    REPLACE ALL OCCURRENCES OF '&' IN rv_out WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_out WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_out WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_out WITH '&quot;'.

  ENDMETHOD.
ENDCLASS.
