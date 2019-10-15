SUBROUTINE Qact_TO_cart(Qact,nb_act,Qcart,nb_cart)
  USE Module_ForTnumTana_Driver
  IMPLICIT NONE

  integer,           intent(in)     :: nb_act,nb_cart

  real (kind=Rkind), intent(in)     :: Qact(nb_act)
  real (kind=Rkind), intent(inout)  :: Qcart(nb_cart)


  character (len=*), parameter :: name_sub='Qact_TO_cart'

!===========================================================
!===========================================================
  !$OMP    CRITICAL (Qact_TO_cart_CRIT)
  IF (Init == 0) THEN
    Init = 1
    CALL versionEVRT(.TRUE.)
    print_level=-1
    !-----------------------------------------------------------------
    !     - read the coordinate transformations :
    !     -   zmatrix, polysperical, bunch...
    !     ------------------------------------------------------------
    CALL Read_mole(mole,para_Tnum,const_phys)
    !     ------------------------------------------------------------
    !-----------------------------------------------------------------

    !-----------------------------------------------------------------
    !     - read coordinate values -----------------------------------
    !     ------------------------------------------------------------
    CALL read_RefGeom(mole,para_Tnum)
    !     ------------------------------------------------------------
    !-----------------------------------------------------------------

    !-----------------------------------------------------------------
    !     ---- TO finalize the coordinates (NM) and the KEO ----------
    !     ------------------------------------------------------------
    para_Tnum%Tana=.FALSE.
    CALL Finalyze_TnumTana_Coord_PrimOp(para_Tnum,mole,para_PES)

    IF (nb_act /= mole%nb_act .OR. nb_cart /= mole%ncart_act) THEN
       write(out_unitp,*) ' ERROR in ', name_sub
       write(out_unitp,*) ' nb_act is different from the Tnum one ',nb_act,mole%nb_act
       write(out_unitp,*) '    or '
       write(out_unitp,*) ' nb_cart is different from the Tnum one ',nb_cart,mole%ncart_act
       STOP
    END IF

  END IF
  !$OMP   END CRITICAL (Qact_TO_cart_CRIT)

!===========================================================
!===========================================================

  CALL sub_QactTOd0x(Qcart,Qact,mole,Gcenter=.FALSE.)


END SUBROUTINE Qact_TO_cart
SUBROUTINE Init_TnumTana_FOR_Driver(nb_act,nb_cart,init_sub)
  USE Module_ForTnumTana_Driver
  IMPLICIT NONE

  integer,           intent(inout)     :: nb_act,nb_cart

  integer,           intent(inout)     :: init_sub

  character (len=*), parameter :: name_sub='Init_TnumTana_FOR_Driver'


  !$OMP    CRITICAL (Init_TnumTana_FOR_Driver_CRIT)
  IF (Init == 0 .OR. init_sub == 0) THEN
    init     = 1
    init_sub = 1

    CALL versionEVRT(.TRUE.)
    print_level=-1
    !-----------------------------------------------------------------
    !     - read the coordinate transformations :
    !     -   zmatrix, polysperical, bunch...
    !     ------------------------------------------------------------
    CALL Read_mole(mole,para_Tnum,const_phys)
    !     ------------------------------------------------------------
    !-----------------------------------------------------------------

    !-----------------------------------------------------------------
    !     - read coordinate values -----------------------------------
    !     ------------------------------------------------------------
    CALL read_RefGeom(mole,para_Tnum)
    !     ------------------------------------------------------------
    !-----------------------------------------------------------------

    !-----------------------------------------------------------------
    !     ---- TO finalize the coordinates (NM) and the KEO ----------
    !     ------------------------------------------------------------
    CALL Finalyze_TnumTana_Coord_PrimOp(para_Tnum,mole,para_PES)

  END IF

  nb_act  = mole%nb_act
  nb_cart = mole%ncart_act
  !$OMP   END CRITICAL (Init_TnumTana_FOR_Driver_CRIT)


END SUBROUTINE Init_TnumTana_FOR_Driver
SUBROUTINE Init_TnumTana_FOR_Driver_FOR_c(nb_act,nb_cart,init_sub)  BIND(C, name="Init_TnumTana_FOR_Driver_FOR_c")
  USE, INTRINSIC :: ISO_C_BINDING, ONLY : C_INT
  IMPLICIT NONE

  integer (kind=C_INT), intent(inout)     :: nb_act,nb_cart
  integer (kind=C_INT), intent(inout)     :: init_sub



  integer               :: nb_act_loc,nb_cart_loc
  integer               :: init_sub_loc

  character (len=*), parameter :: name_sub='Init_TnumTana_FOR_Driver_FOR_c'



  CALL Init_TnumTana_FOR_Driver(nb_act_loc,nb_cart_loc,init_sub_loc)


  nb_act   = nb_act_loc
  nb_cart  = nb_cart_loc
  init_sub = init_sub_loc


END SUBROUTINE Init_TnumTana_FOR_Driver_FOR_c
SUBROUTINE Qact_TO_Qcart_TnumTanaDriver_FOR_c(Qact,nb_act,Qcart,nb_cart) BIND(C, name="Qact_TO_Qcart_TnumTanaDriver_FOR_c")
  USE, INTRINSIC :: ISO_C_BINDING,             ONLY : C_INT,C_DOUBLE
  USE            :: mod_system,                ONLY : Rkind,out_unitp
  USE            :: Module_ForTnumTana_Driver, ONLY : mole,init,sub_QactTOd0x
  IMPLICIT NONE

  integer (kind=C_INT), intent(in)     :: nb_act,nb_cart

  real (kind=C_DOUBLE), intent(in)     :: Qact(nb_act)
  real (kind=C_DOUBLE), intent(inout)  :: Qcart(nb_cart)


  !- local parameters for para_Tnum -----------------------
  real (kind=Rkind)      :: Qact_loc(nb_act)
  real (kind=Rkind)      :: Qcart_loc(nb_cart)


  character (len=*), parameter :: name_sub='Qact_TO_Qcart_TnumTanaDriver_FOR_c'


  IF (Init == 0) THEN
    write(out_unitp,*) ' ERROR in ', name_sub
    write(out_unitp,*) '   The intialization IS NOT done!'
    write(out_unitp,*) ' First, you MUST call Init_TnumTana_FOR_Driver_FOR_c'
    STOP
  END IF
  IF (nb_act /= mole%nb_act .OR. nb_cart /= mole%ncart_act) THEN
     write(out_unitp,*) ' ERROR in ', name_sub
     write(out_unitp,*) ' nb_act is different from the Tnum one ',nb_act,mole%nb_act
     write(out_unitp,*) '    or '
     write(out_unitp,*) ' nb_cart is different from the Tnum one ',nb_cart,mole%ncart_act
     STOP
  END IF

  Qact_loc(:)  = Qact
  CALL sub_QactTOd0x(Qcart_loc,Qact_loc,mole,Gcenter=.FALSE.)
  Qcart(:)     = Qcart_loc

END SUBROUTINE Qact_TO_Qcart_TnumTanaDriver_FOR_c
SUBROUTINE Qcart_TO_Qact_TnumTanaDriver_FOR_c(Qact,nb_act,Qcart,nb_cart) BIND(C, name="Qcart_TO_Qact_TnumTanaDriver_FOR_c")
  USE, INTRINSIC :: ISO_C_BINDING,             ONLY : C_INT,C_DOUBLE
  USE            :: mod_system,                ONLY : Rkind,out_unitp
  USE            :: Module_ForTnumTana_Driver, ONLY : mole,Init,sub_d0xTOQact
  IMPLICIT NONE

  integer (kind=C_INT), intent(in)     :: nb_act,nb_cart

  real (kind=C_DOUBLE), intent(inout)  :: Qact(nb_act)
  real (kind=C_DOUBLE), intent(in)     :: Qcart(nb_cart)


  !- local parameters for para_Tnum -----------------------
  real (kind=Rkind)      :: Qact_loc(nb_act)
  real (kind=Rkind)      :: Qcart_loc(nb_cart)


  character (len=*), parameter :: name_sub='Qcart_TO_Qact_TnumTanaDriver_FOR_c'


  IF (Init == 0) THEN
    write(out_unitp,*) ' ERROR in ', name_sub
    write(out_unitp,*) '   The intialization IS NOT done!'
    write(out_unitp,*) ' First, you MUST call Init_TnumTana_FOR_Driver_FOR_c'
    STOP
  END IF
  IF (nb_act /= mole%nb_act .OR. nb_cart /= mole%ncart_act) THEN
     write(out_unitp,*) ' ERROR in ', name_sub
     write(out_unitp,*) ' nb_act is different from the Tnum one ',nb_act,mole%nb_act
     write(out_unitp,*) '    or '
     write(out_unitp,*) ' nb_cart is different from the Tnum one ',nb_cart,mole%ncart_act
     STOP
  END IF

  Qcart_loc(:) = Qcart(:)
  CALL sub_d0xTOQact(Qcart_loc,Qact_loc,mole)
  Qact(:)      = Qact_loc(:)


END SUBROUTINE Qcart_TO_Qact_TnumTanaDriver_FOR_c