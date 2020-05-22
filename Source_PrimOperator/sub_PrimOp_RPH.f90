!===========================================================================
!===========================================================================
!This file is part of ElVibRot.
!
!    ElVibRot is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    ElVibRot is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with ElVibRot.  If not, see <http://www.gnu.org/licenses/>.
!
!    Copyright 2015 David Lauvergnat [1]
!      with contributions of
!        Josep Maria Luis (optimization) [2]
!        Ahai Chen (MPI) [1,4]
!        Lucien Dupuy (CRP) [5]
!
![1]: Institut de Chimie Physique, UMR 8000, CNRS-Université Paris-Saclay, France
![2]: Institut de Química Computacional and Departament de Química,
!        Universitat de Girona, Catalonia, Spain
![3]: Department of Chemistry, Aarhus University, DK-8000 Aarhus C, Denmark
![4]: Maison de la Simulation USR 3441, CEA Saclay, France
![5]: Laboratoire Univers et Particule de Montpellier, UMR 5299,
!         Université de Montpellier, France
!
!    ElVibRot includes:
!        - Tnum-Tana under the GNU LGPL3 license
!        - Somme subroutines of John Burkardt under GNU LGPL license
!             http://people.sc.fsu.edu/~jburkardt/
!        - Somme subroutines of SHTOOLS written by Mark A. Wieczorek under BSD license
!             http://shtools.ipgp.fr
!        - Some subroutine of QMRPack (see cpyrit.doc) Roland W. Freund and Noel M. Nachtigal:
!             https://www.netlib.org/linalg/qmr/
!
!===========================================================================
!===========================================================================
   MODULE mod_PrimOp_RPH
   USE mod_nDFit
   USE mod_PrimOp_def
   USE mod_OTF_def
   USE mod_OTF
   USE mod_SimpleOp
   IMPLICIT NONE

   PRIVATE
   PUBLIC :: Set_RPHpara_AT_Qact1,sub_dnfreq_4p_cHAC,sub_freq2_RPH,sub_dnfreq_v3

   CONTAINS

  SUBROUTINE CoordQact_TO_RPHQact1(Qact,RPHpara_AT_Qact1,mole)
    USE mod_system
    USE mod_Coord_KEO
    IMPLICIT NONE


    !----- for the CoordType and Tnum --------------------------------------
    real (kind=Rkind),            intent(in)    :: Qact(:)
    TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
    TYPE (CoordType),             intent(inout) :: mole


    integer                        :: i_Qact,i
    real (kind=Rkind), allocatable :: Qit(:)

    !-----------------------------------------------------------
    integer :: err_mem,memory
    character (len=*), parameter :: name_sub='CoordQact_TO_RPHQact1'
    logical, parameter :: debug = .FALSE.
    !logical, parameter :: debug = .TRUE.
    !-----------------------------------------------------------
    IF (debug) THEN
      write(out_unitp,*) 'BEGINNING ',name_sub
      write(out_unitp,*) ' Qact',Qact(:)
      CALL flush_perso(out_unitp)
    END IF
    !-----------------------------------------------------------

    IF (.NOT. associated(mole%RPHTransfo) .OR. mole%itRPH == -1) THEN
      write(out_unitp,*) ' ERROR in ',name_sub
      write(out_unitp,*) ' RPHTransfo is not associated or itRPH=-1'
      write(out_unitp,*) ' asso mole%RPHTransfo',associated(mole%RPHTransfo)
      write(out_unitp,*) ' itRPH',mole%itRPH
      STOP ' ERROR in CoordQact_TO_RPHQact1: RPHTransfo is not associated'
    END IF

    CALL sub_QactTOQit(Qact,Qit,mole%itRPH,mole,print_Qtransfo=.FALSE.)
    IF (debug) write(out_unitp,*) ' Qit',Qit(:)

    i_Qact = 0
    DO i=1,mole%nb_var
      IF (mole%RPHTransfo%list_act_OF_Qdyn(i) == 1) THEN
        i_Qact = i_Qact + 1
        RPHpara_AT_Qact1%RPHQact1(i_Qact) = Qit(i)
      END IF
    END DO

    CALL dealloc_NParray(Qit,'Qit',name_sub)

    IF (debug) THEN
      write(out_unitp,*) ' RPHQact1',RPHpara_AT_Qact1%RPHQact1(:)
      write(out_unitp,*) 'END ',name_sub
     CALL flush_perso(out_unitp)
    END IF

  END SUBROUTINE CoordQact_TO_RPHQact1
  SUBROUTINE RPHQact1_TO_CoordQact(Qact,RPHpara_AT_Qact1,mole)
    USE mod_system
    USE mod_Coord_KEO
    IMPLICIT NONE


    !----- for the CoordType and Tnum --------------------------------------
    real (kind=Rkind),            intent(inout) :: Qact(:)
    TYPE (Type_RPHpara_AT_Qact1), intent(in)    :: RPHpara_AT_Qact1
    TYPE (CoordType),             intent(in)    :: mole


    integer                        :: i_Qact,i
    real (kind=Rkind), allocatable :: Qit(:)

    !-----------------------------------------------------------
    integer :: err_mem,memory
    character (len=*), parameter :: name_sub='RPHQact1_TO_CoordQact'
    logical, parameter :: debug = .FALSE.
    !logical, parameter :: debug = .TRUE.
    !-----------------------------------------------------------
    IF (debug) THEN
      write(out_unitp,*) 'BEGINNING ',name_sub
      write(out_unitp,*) ' RPHQact1',RPHpara_AT_Qact1%RPHQact1(:)
      CALL flush_perso(out_unitp)
    END IF
    !-----------------------------------------------------------

    IF (.NOT. associated(mole%RPHTransfo) .OR. mole%itRPH == -1) THEN
      write(out_unitp,*) ' ERROR in ',name_sub
      write(out_unitp,*) ' RPHTransfo is not associated or itRPH=-1'
      write(out_unitp,*) ' asso mole%RPHTransfo',associated(mole%RPHTransfo)
      write(out_unitp,*) ' itRPH',mole%itRPH
      STOP ' ERROR in RPHQact1_TO_CoordQact: RPHTransfo is not associated'
    END IF

    CALL alloc_NParray(Qit,[mole%nb_var],'Qit',name_sub)


    i_Qact = 0
    DO i=1,mole%nb_var
      IF (mole%RPHTransfo%list_act_OF_Qdyn(i) == 1) THEN
        i_Qact = i_Qact + 1
        Qit(i) = RPHpara_AT_Qact1%RPHQact1(i_Qact)
      END IF
    END DO
    IF (debug) write(out_unitp,*) ' Qit',Qit(:)

    CALL sub_QinRead_TO_Qact(Qit,Qact,mole,mole%itRPH)

    CALL dealloc_NParray(Qit,'Qit',name_sub)

    IF (debug) THEN
      write(out_unitp,*) ' Qact',Qact(:)
      write(out_unitp,*) 'END ',name_sub
     CALL flush_perso(out_unitp)
    END IF

  END SUBROUTINE RPHQact1_TO_CoordQact

  SUBROUTINE Set_RPHpara_AT_Qact1(RPHpara_AT_Qact1,Qact,para_Tnum,mole)
    USE mod_system
    USE mod_Coord_KEO
    IMPLICIT NONE

    !----- for the CoordType and Tnum --------------------------------------
    TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
    TYPE (Tnum),                  intent(in)    :: para_Tnum
    TYPE (CoordType),             intent(inout) :: mole

    real (kind=Rkind),            intent(in)    :: Qact(:)


    !-----------------------------------------------------------
    integer :: err_mem,memory
    character (len=*), parameter :: name_sub='Set_RPHpara_AT_Qact1'
    logical, parameter :: debug = .FALSE.
    !logical, parameter :: debug = .TRUE.
    !-----------------------------------------------------------
    IF (debug) THEN
      write(out_unitp,*) 'BEGINNING ',name_sub
      write(out_unitp,*) 'RPHTransfo%option',mole%RPHTransfo%option
      CALL flush_perso(out_unitp)
    END IF
    !-----------------------------------------------------------
    IF (.NOT. associated(mole%RPHTransfo) .OR. mole%itRPH == -1) THEN
      write(out_unitp,*) ' ERROR in ',name_sub
      write(out_unitp,*) ' RPHTransfo is not associated or itRPH=-1'
      write(out_unitp,*) ' asso mole%RPHTransfo',associated(mole%RPHTransfo)
      write(out_unitp,*) ' itRPH',mole%itRPH
      STOP ' ERROR in Set_RPHpara_AT_Qact1_opt01_v2: RPHTransfo is not associated'
    END IF

    IF (mole%RPHTransfo%option == 2) THEN
      CALL Set_RPHpara_AT_Qact1_opt2(RPHpara_AT_Qact1,                  &
                                     Qact,para_Tnum,mole,mole%RPHTransfo)
    ELSE ! option 0 ou 1
      CALL Set_RPHpara_AT_Qact1_opt01_v2(RPHpara_AT_Qact1,Qact,para_Tnum,mole)
      !CALL Set_RPHpara_AT_Qact1_opt01_v1(RPHpara_AT_Qact1,Qact,para_Tnum,&
      !                                              mole,mole%RPHTransfo)
    END IF

    IF (debug) THEN
      CALL Write_RPHpara_AT_Qact1(RPHpara_AT_Qact1)
      write(out_unitp,*) 'END ',name_sub
      CALL flush_perso(out_unitp)
    END IF

  END SUBROUTINE Set_RPHpara_AT_Qact1

      SUBROUTINE Set_RPHpara_AT_Qact1_opt2(RPHpara_AT_Qact1,            &
                                           Qact_in,para_Tnum,mole,RPHTransfo)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE


      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      integer :: nb_act1,nb_inact21

      TYPE (Tnum)             :: para_Tnum
      TYPE (CoordType)        :: mole
      TYPE (Type_RPHTransfo)  :: RPHTransfo

      real (kind=Rkind), intent(in) :: Qact_in(:)



      !------ for the frequencies -------------------------------
      integer               :: nderiv
      real (kind=Rkind)     :: auTOcm_inv
      integer               :: i,iact,idyn,RPHoption,iref,nb_ref
      real (kind=Rkind)     :: Qdyn(mole%nb_var)
      real (kind=Rkind)     :: Qact(mole%nb_var)

      integer               :: iact1,iq,jq,iQinact21,jQinact21
      integer               :: listNM_selected(mole%nb_var)


      TYPE (Type_dnS), pointer   :: dnSwitch(:)
      TYPE (Type_dnS)            :: dnW1
      real (kind=Rkind)          :: sc,det

      TYPE (Type_dnVec)                  :: dnQact
      real (kind=Rkind), allocatable     :: QrefQact(:,:)     ! QrefQact(nb_Qact1,nb_ref)

      !-----------------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='Set_RPHpara_AT_Qact1_opt2'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
      !-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        CALL flush_perso(out_unitp)
      END IF
      !-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      Qact = Qact_in

      nderiv     = 3
      IF (para_Tnum%vep_type == 0) nderiv = 2

      nb_act1    = RPHTransfo%nb_act1
      nb_inact21 = RPHTransfo%nb_inact21
      nb_ref     = RPHTransfo%RPHpara2%nb_ref

      CALL alloc_RPHpara_AT_Qact1(RPHpara_AT_Qact1,nb_act1,nb_inact21,nderiv)


      !here it should be Qin of RPH (therefore Qdyn ?????)
      CALL Qact_TO_Qdyn_FROM_ActiveTransfo(Qact,Qdyn,mole%ActiveTransfo)

      RPHpara_AT_Qact1%RPHQact1(:) = Qdyn(RPHTransfo%list_QactTOQdyn(1:nb_act1))

      ! 1st: dnQact (derivatives, just for the active coordinates)
      CALL alloc_dnSVM(dnQact,  nb_act1,nb_act1,           nderiv)
      dnQact%d0(:) = RPHpara_AT_Qact1%RPHQact1(:)
      CALL Set_AllActive(dnQact)

      ! 2d: the reference Qact
      CALL alloc_NParray(QrefQact,(/ nb_act1,nb_ref /),'QrefQact',name_sub)
      QrefQact(:,:) = RPHTransfo%RPHpara2%QoutRef(1:nb_act1,:)

      ! 3d: dnSwitch
      sc = TWO ! to be changed, from Read_RPHpara2
      nullify(dnSwitch)
      CALL alloc_array(dnSwitch,(/nb_ref/),"dnSwitch",name_sub)
      CALL alloc_VecOFdnS(dnSwitch,nb_act1,nderiv)
      CALL Switch_RPH(dnSwitch,dnQact,QrefQact,sc,nderiv)
      !write(out_unitp,*) 'dnSwitch(:)',dnSwitch(:)%d0

      CALL alloc_dnSVM(dnW1,  nb_act1,           nderiv)

      ! 4th: dnQopt
      !old (one ref)
      CALL sub_ZERO_TO_dnVec(RPHpara_AT_Qact1%dnQopt)
      DO iQinact21=1,nb_inact21
        CALL sub_ZERO_TO_dnS(dnW1)
        DO iref=1,nb_ref
          !dnW1 = dnW1 + dnSwitch(iref)*RPHTransfo%RPHpara2%QoutRef(nb_act1+iQinact21,iref)
          CALL sub_dnS1_wPLUS_dnS2_TO_dnS2(dnSwitch(iref),              &
                    RPHTransfo%RPHpara2%QoutRef(nb_act1+iQinact21,iref),&
                                           dnW1,ONE)
        END DO
        CALL sub_dnS_TO_dnVec(dnW1,RPHpara_AT_Qact1%dnQopt,iQinact21)
      END DO
      !write(99,*) 'Qact,Qopt',dnQact%d0(:),RPHpara_AT_Qact1%dnQopt%d0

      !5th: dnC_inv
      CALL sub_ZERO_TO_dnMat(RPHpara_AT_Qact1%dnC_inv)
      listNM_selected(:) = 0
      DO iact1=1,nb_act1
        listNM_selected(RPHTransfo%RPHpara2%listNM_act1(iact1)) = 1
      END DO

      iQinact21 = 0
      DO iq=1,nb_act1+nb_inact21
        IF (listNM_selected(iq) /= 0) CYCLE
        iQinact21 = iQinact21 + 1

        DO jQinact21=1,nb_inact21

          CALL sub_ZERO_TO_dnS(dnW1)
          DO iref=1,nb_ref
            CALL sub_dnS1_wPLUS_dnS2_TO_dnS2(dnSwitch(iref),            &
                RPHTransfo%RPHpara2%CinvRef(iq,nb_act1+jQinact21,iref), &
                                             dnW1,ONE)
          END DO
          CALL sub_dnS_TO_dnMat(dnW1,RPHpara_AT_Qact1%dnC_inv,iQinact21,jQinact21)


        END DO
      END DO

      CALL dealloc_dnSVM(dnQact)
      CALL dealloc_NParray(QrefQact,'QrefQact',name_sub)

      CALL dealloc_VecOFdnS(dnSwitch)
      CALL dealloc_array(dnSwitch,"dnSwitch",name_sub)
      nullify(dnSwitch)

      CALL dealloc_dnSVM(dnW1)


      ! just dnC%d0
      CALL inv_m1_TO_m2(RPHpara_AT_Qact1%dnC_inv%d0,RPHpara_AT_Qact1%dnC%d0, &
                        nb_inact21,0,ZERO)


     RPHpara_AT_Qact1%init_done = 2


     IF (debug) THEN
        CALL Write_RPHpara_AT_Qact1(RPHpara_AT_Qact1)
        write(out_unitp,*) 'END ',name_sub
        CALL flush_perso(out_unitp)
     END IF

     END SUBROUTINE Set_RPHpara_AT_Qact1_opt2

      SUBROUTINE Set_RPHpara_AT_Qact1_opt01_v2(RPHpara_AT_Qact1,        &
                                               Qact,para_Tnum,mole)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE


      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      TYPE (Tnum),                  intent(in)    :: para_Tnum
      TYPE (CoordType),             intent(inout) :: mole

      real (kind=Rkind),            intent(in)    :: Qact(:)


      integer               :: nderiv
      real (kind=Rkind)     :: pot0_corgrad,auTOcm_inv

      !-----------------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='Set_RPHpara_AT_Qact1_opt01_v2'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
      !-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        CALL flush_perso(out_unitp)
      END IF
      !-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

    IF (.NOT. associated(mole%RPHTransfo) .OR. mole%itRPH == -1) THEN
      write(out_unitp,*) ' ERROR in ',name_sub
      write(out_unitp,*) ' RPHTransfo is not associated or itRPH=-1'
      write(out_unitp,*) ' asso mole%RPHTransfo',associated(mole%RPHTransfo)
      write(out_unitp,*) ' itRPH',mole%itRPH
      STOP ' ERROR in Set_RPHpara_AT_Qact1_opt01_v2: RPHTransfo is not associated'
    END IF

      nderiv     = 3
      IF (para_Tnum%vep_type == 0) nderiv = 2

      CALL alloc_RPHpara_AT_Qact1(RPHpara_AT_Qact1,                     &
                                  mole%RPHTransfo%nb_act1,              &
                                  mole%RPHTransfo%nb_inact21,nderiv)

      CALL CoordQact_TO_RPHQact1(Qact,RPHpara_AT_Qact1,mole)

      !CALL sub_dnfreq_8p_v2(RPHpara_AT_Qact1,pot0_corgrad,              &
      !                      para_Tnum,mole,mole%RPHTransfo,nderiv,.FALSE.)
      CALL sub_dnfreq_v3(RPHpara_AT_Qact1,pot0_corgrad,                 &
                            para_Tnum,mole,mole%RPHTransfo,nderiv,      &
                            test=.FALSE.,cHAC=.FALSE.)

     write(out_unitp,11) RPHpara_AT_Qact1%RPHQact1(:),                  &
                         RPHpara_AT_Qact1%dnEHess%d0(:)*auTOcm_inv
 11  format(' frequencies : ',30f10.4)

     RPHpara_AT_Qact1%init_done = 2

     IF (debug) THEN
       CALL Write_RPHpara_AT_Qact1(RPHpara_AT_Qact1)
       write(out_unitp,*) 'END ',name_sub
       CALL flush_perso(out_unitp)
     END IF

     END SUBROUTINE Set_RPHpara_AT_Qact1_opt01_v2
     SUBROUTINE Set_RPHpara_AT_Qact1_opt01_v1(RPHpara_AT_Qact1,           &
                                         Qact_in,para_Tnum,mole,RPHTransfo)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE


      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      integer :: nb_act1,nb_inact21

      TYPE (Tnum)             :: para_Tnum
      TYPE (CoordType)        :: mole
      TYPE (Type_RPHTransfo)  :: RPHTransfo

      real (kind=Rkind), intent(in) :: Qact_in(:)



      !------ for the frequencies -------------------------------
      TYPE (Type_dnMat)     :: dnC,dnC_inv      ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnQeq            ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnEHess          ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnGrad           ! derivative with respect to Qact1
      TYPE (Type_dnMat)     :: dnHess           ! derivative with respect to Qact1
      TYPE (Type_dnS)       :: dnLnN            ! derivative with respect to Qact1
      integer               :: nderiv
      real (kind=Rkind)     :: pot0_corgrad,stepp,step_loc,vi,auTOcm_inv
      integer               :: i,iact,idyn,RPHoption
      real (kind=Rkind)     :: Qdyn(mole%nb_var)
      real (kind=Rkind)     :: Qact(mole%nb_var)

      !-----------------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='Set_RPHpara_AT_Qact1_opt01_v1'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
      !-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        CALL flush_perso(out_unitp)
      END IF
      !-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      nderiv     = 3
      IF (para_Tnum%vep_type == 0) nderiv = 2

      step_loc   = RPHTransfo%step
      stepp      = ONE/(step_loc+step_loc)

      nb_act1    = RPHTransfo%nb_act1
      nb_inact21 = RPHTransfo%nb_inact21

      CALL alloc_RPHpara_AT_Qact1(RPHpara_AT_Qact1,nb_act1,nb_inact21,nderiv)



      RPHoption = RPHTransfo%option
      CALL Sub_paraRPH_TO_CoordType(mole) ! switch back mole
      mole%tab_Qtransfo(mole%itRPH)%skip_transfo = .TRUE. ! we have to skip RPH transfo because, ...
                                                          ! this subroutine calculates the RPH parameters

      CALL alloc_dnSVM(dnC,    nb_inact21,nb_inact21,nb_act1,nderiv)
      CALL alloc_dnSVM(dnC_inv,nb_inact21,nb_inact21,nb_act1,nderiv)
      CALL alloc_dnSVM(dnQeq,  nb_inact21,nb_act1,           nderiv)
      CALL alloc_dnSVM(dnEHess,nb_inact21,nb_act1,           nderiv)
      CALL alloc_dnSVM(dnHess, nb_inact21,nb_inact21,nb_act1,nderiv)
      CALL alloc_dnSVM(dnGrad, nb_inact21,nb_act1,           nderiv)
      CALL alloc_dnSVM(dnLnN,  nb_act1,                      nderiv)

      CALL CoordQact_TO_RPHQact1(Qact_in,RPHpara_AT_Qact1,mole)
      Qact = Qact_in

      CALL sub_dnfreq_8p(RPHpara_AT_Qact1%dnQopt,RPHpara_AT_Qact1%dnC,  &
                        RPHpara_AT_Qact1%dnLnN,RPHpara_AT_Qact1%dnEHess,&
                        RPHpara_AT_Qact1%dnhess,dnGrad,                 &
                        RPHpara_AT_Qact1%dnC_inv,pot0_corgrad,          &
                        Qact,para_Tnum,mole,RPHTransfo,nderiv,.FALSE.)

     IF (debug) THEN
       write(out_unitp,*) 'dnC_inv'
       CALL Write_dnMat(RPHpara_AT_Qact1%dnC_inv,nderiv=0)
     END IF

     IF (nderiv == 3) THEN
       DO i=1,nb_act1

         idyn = RPHTransfo%list_QactTOQdyn(i)
         iact = mole%liste_QdynTOQact(idyn)
         vi = Qact(iact)

         !-- frequencies calculation at Qact(i)+step -------------
         Qact(iact)      = vi + step_loc

         CALL sub_dnfreq_8p(dnQeq,dnC,dnLnN,dnEHess,dnhess,dnGrad,dnC_inv, &
                         pot0_corgrad,Qact,    &
                         para_Tnum,mole,RPHTransfo,nderiv,.FALSE.)

         RPHpara_AT_Qact1%dnLnN%d3(:,:,i)         = dnLnN%d2(:,:)

         RPHpara_AT_Qact1%dnC%d3(:,:,:,:,i)       = dnC%d2(:,:,:,:)
         RPHpara_AT_Qact1%dnC_inv%d3(:,:,:,:,i)   = dnC_inv%d2(:,:,:,:)
         RPHpara_AT_Qact1%dnhess%d3(:,:,:,:,i)    = dnHess%d2(:,:,:,:)

         RPHpara_AT_Qact1%dnEHess%d3(:,:,:,i)     = dnEHess%d2(:,:,:)
         RPHpara_AT_Qact1%dnQopt%d3(:,:,:,i)      = dnQeq%d2(:,:,:)

         !-- frequencies calculation at Qact(i)-step -------------
         Qact(iact)      = vi - step_loc

         CALL sub_dnfreq_8p(dnQeq,dnC,dnLnN,dnEHess,dnhess,dnGrad,dnC_inv, &
                            pot0_corgrad,Qact,    &
                            para_Tnum,mole,RPHTransfo,nderiv,.FALSE.)

         RPHpara_AT_Qact1%dnLnN%d3(:,:,i)         =                     &
                                (RPHpara_AT_Qact1%dnLnN%d3(:,:,i)      -&
                                                    dnLnN%d2(:,:))*stepp

         RPHpara_AT_Qact1%dnC%d3(:,:,:,:,i)       =                     &
                                (RPHpara_AT_Qact1%dnC%d3(:,:,:,:,i)    -&
                                                  dnC%d2(:,:,:,:))*stepp
         RPHpara_AT_Qact1%dnC_inv%d3(:,:,:,:,i)   =                     &
                                (RPHpara_AT_Qact1%dnC_inv%d3(:,:,:,:,i)-&
                                              dnC_inv%d2(:,:,:,:))*stepp
         RPHpara_AT_Qact1%dnhess%d3(:,:,:,:,i)    =                     &
                                (RPHpara_AT_Qact1%dnhess%d3(:,:,:,:,i) -&
                                               dnHess%d2(:,:,:,:))*stepp

         RPHpara_AT_Qact1%dnEHess%d3(:,:,:,i)     =                     &
                                (RPHpara_AT_Qact1%dnEHess%d3(:,:,:,i)  -&
                                                dnEHess%d2(:,:,:))*stepp
         RPHpara_AT_Qact1%dnQopt%d3(:,:,:,i)      =                     &
                               (RPHpara_AT_Qact1%dnQopt%d3(:,:,:,i)    -&
                                                  dnQeq%d2(:,:,:))*stepp

         Qact(iact)      = vi
       END DO
     END IF

     write(out_unitp,11) Qact(1:RPHTransfo%nb_act1),                    &
                               RPHpara_AT_Qact1%dnEHess%d0(:)*auTOcm_inv
 11  format(' frequencies : ',30f10.4)

     CALL dealloc_dnSVM(dnC)
     CALL dealloc_dnSVM(dnC_inv)
     CALL dealloc_dnSVM(dnQeq)
     CALL dealloc_dnSVM(dnEHess)
     CALL dealloc_dnSVM(dnHess)
     CALL dealloc_dnSVM(dnGrad)
     CALL dealloc_dnSVM(dnLnN)

     mole%tab_Qtransfo(mole%itRPH)%skip_transfo = .FALSE.
     CALL Sub_CoordType_TO_paraRPH(mole)
     RPHTransfo%option = RPHoption

     RPHpara_AT_Qact1%init_done = 2

     IF (debug) THEN
        CALL Write_RPHpara_AT_Qact1(RPHpara_AT_Qact1)
        write(out_unitp,*) 'END ',name_sub
        CALL flush_perso(out_unitp)
     END IF

     END SUBROUTINE Set_RPHpara_AT_Qact1_opt01_v1
!
!=============================================================
!
!     numerical derivative frequency calculations
!
!=============================================================
      SUBROUTINE sub_dnfreq_v3(RPHpara_AT_Qact1,pot0_corgrad,          &
                               para_Tnum,mole,RPHTransfo,nderiv,test,cHAC)
      USE mod_system
      USE mod_dnSVM
      USE mod_FiniteDiff
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      USE CurviRPH_mod
      IMPLICIT NONE


!----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      TYPE (Tnum)                                 :: para_Tnum
      TYPE (CoordType),             intent(inout) :: mole
      TYPE (Type_RPHTransfo),       intent(inout) :: RPHTransfo
      real (kind=Rkind)                           :: pot0_corgrad
      integer,                      intent(in)    :: nderiv
      logical,                      intent(in)    :: test,cHAC



!----- working variables -----------------------------------------------
!----- For the derivatives ---------------------------------------------
    integer                          :: i,j,k,ip,jp,kp
    integer                          :: i_pt,nb_pts,ind1DQ(1),ind2DQ(2),ind3DQ(3)
    real (kind=Rkind)                :: pot0_corgrad2
      TYPE (Type_RPHpara_AT_Qact1)   :: RPHpara_AT_Qact1_save
    real (kind=Rkind), allocatable   :: Qact1(:)


      real (kind=Rkind)              ::  auTOcm_inv

!----- for debuging --------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='sub_dnfreq_v3'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
        write(out_unitp,*) 'BEGINNING ',name_sub
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

!-----------------------------------------------------------
      CALL alloc_NParray(Qact1,[RPHTransfo%nb_act1],'Qact1',name_sub)
      Qact1(:) = RPHpara_AT_Qact1%RPHQact1

      IF (RPHTransfo%step <= ZERO) THEN
        write(out_unitp,*) ' ERROR : RPHTransfo%step is < zero'
        STOP
      END IF

!-----------------------------------------------------------------
!----- frequencies calculation at Qact1 --------------------------
!            no derivative
!-----------------------------------------------------------------
    CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,                &
                                          para_Tnum,mole,RPHTransfo,cHAC)

    ! save RPHpara_AT_Qact1 => RPHpara_AT_Qact1_save (for the numerical derivatives)
    CALL RPHpara1_AT_Qact1_TO_RPHpara2_AT_Qact1(RPHpara_AT_Qact1,       &
                                                  RPHpara_AT_Qact1_save)

    ! update RPHpara_AT_Qact1_save from RPHpara_AT_Qact1
    CALL FinitDiff_AddVec_TO_dnVec(RPHpara_AT_Qact1_save%dnQopt,        &
                                   RPHpara_AT_Qact1%dnQopt%d0,option=3)
    CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC_inv,       &
                                   RPHpara_AT_Qact1%dnC_inv%d0,option=3)
    IF (cHAC) THEN
      CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC,         &
                                     RPHpara_AT_Qact1%dnC%d0,option=3)
      CALL FinitDiff_AddR_TO_dnS(RPHpara_AT_Qact1_save%dnLnN,           &
                                 RPHpara_AT_Qact1%dnLnN%d0,option=3)
    END IF


!-----------------------------------------------------------------
!----- Finite differencies along Qact1(i) ------------------------
!  =>    d/Qqi, d2/dQi2 and d3/dQi3
!-----------------------------------------------------------------
    IF (nderiv >= 1) THEN ! 1st derivatives
      DO i=1,RPHTransfo%nb_act1
        DO i_pt=1,Get_nb_pts(1)

          CALL Get_indDQ(ind1DQ,i_pt)
          CALL Set_QplusDQ(RPHpara_AT_Qact1%RPHQact1,Qact1,indQ=[i],    &
                                   indDQ=ind1DQ,step_sub=RPHTransfo%step)

          ! frequencies at RPHpara_AT_Qact1%Qact1
          CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad2,         &
                                          para_Tnum,mole,RPHTransfo,cHAC)

          ! update RPHpara_AT_Qact1_save from RPHpara_AT_Qact1
          CALL FinitDiff_AddVec_TO_dnVec(RPHpara_AT_Qact1_save%dnQopt,  &
                                         RPHpara_AT_Qact1%dnQopt%d0,    &
                                         indQ=[i],indDQ=ind1DQ,option=3)
          CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC_inv, &
                                         RPHpara_AT_Qact1%dnC_inv%d0,   &
                                         indQ=[i],indDQ=ind1DQ,option=3)
          IF (cHAC) THEN
            CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC,   &
                                         RPHpara_AT_Qact1%dnC%d0,       &
                                         indQ=[i],indDQ=ind1DQ,option=3)
            CALL FinitDiff_AddR_TO_dnS(RPHpara_AT_Qact1_save%dnLnN,     &
                                         RPHpara_AT_Qact1%dnLnN%d0,     &
                                         indQ=[i],indDQ=ind1DQ,option=3)
          END IF
        END DO
      END DO
    END IF

!-----------------------------------------------------------------
!----- Finite differencies along Qact1(i) and Qact1(j) -----------
!  =>    d2/dQidQj and d3/dQi2dQj
!-----------------------------------------------------------------
    IF (nderiv >= 2) THEN ! 2d derivatives

      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1

        DO i_pt=1,Get_nb_pts(2)
          CALL Get_indDQ(ind2DQ,i_pt)
          CALL Set_QplusDQ(RPHpara_AT_Qact1%RPHQact1,Qact1,indQ=[i,j],  &
                                   indDQ=ind2DQ,step_sub=RPHTransfo%step)

          ! frequencies at RPHpara_AT_Qact1%Qact1
          CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad2,         &
                                          para_Tnum,mole,RPHTransfo,cHAC)

          ! update RPHpara_AT_Qact1_save from RPHpara_AT_Qact1
          CALL FinitDiff_AddVec_TO_dnVec(RPHpara_AT_Qact1_save%dnQopt,  &
                                         RPHpara_AT_Qact1%dnQopt%d0,    &
                                        indQ=[i,j],indDQ=ind2DQ,option=3)
          CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC_inv, &
                                         RPHpara_AT_Qact1%dnC_inv%d0,   &
                                        indQ=[i,j],indDQ=ind2DQ,option=3)
          IF (cHAC) THEN
            CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC,   &
                                         RPHpara_AT_Qact1%dnC%d0,       &
                                         indQ=[i,j],indDQ=ind2DQ,option=3)
            CALL FinitDiff_AddR_TO_dnS(RPHpara_AT_Qact1_save%dnLnN,     &
                                         RPHpara_AT_Qact1%dnLnN%d0,     &
                                         indQ=[i,j],indDQ=ind2DQ,option=3)
          END IF
        END DO

        CALL FinitDiff3_SymPerm_OF_dnVec(                               &
                                RPHpara_AT_Qact1_save%dnQopt,indQ=[i,j])
        CALL FinitDiff3_SymPerm_OF_dnMat(                               &
                                RPHpara_AT_Qact1_save%dnC_inv,indQ=[i,j])
        IF (cHAC) THEN
          CALL FinitDiff3_SymPerm_OF_dnMat(                             &
                                   RPHpara_AT_Qact1_save%dnC,indQ=[i,j])
          CALL FinitDiff3_SymPerm_OF_dnS(                               &
                                 RPHpara_AT_Qact1_save%dnLnN,indQ=[i,j])
        END IF
      END DO
      END DO
    END IF

!-----------------------------------------------------------------
!----- Finite differencies along Qact1(i),Qact1(j) and Qact1(k) --
!  =>    d3/dQidQjdQk
!-----------------------------------------------------------------
    IF (nderiv >= 3) THEN ! 3d derivatives: d3/dQidQidQj

      ! d3/dQidQjdQk
      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1
      DO k=j+1,RPHTransfo%nb_act1

        DO i_pt=1,Get_nb_pts(3)
          CALL Get_indDQ(ind3DQ,i_pt)
          CALL Set_QplusDQ(RPHpara_AT_Qact1%RPHQact1,Qact1,indQ=[i,j,k],&
                                   indDQ=ind3DQ,step_sub=RPHTransfo%step)

          ! frequencies at RPHpara_AT_Qact1%Qact1
          CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad2,         &
                                          para_Tnum,mole,RPHTransfo,cHAC)

          ! update RPHpara_AT_Qact1_save from RPHpara_AT_Qact1
          CALL FinitDiff_AddVec_TO_dnVec(RPHpara_AT_Qact1_save%dnQopt,  &
                                         RPHpara_AT_Qact1%dnQopt%d0,    &
                                      indQ=[i,j,k],indDQ=ind3DQ,option=3)
          CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC_inv, &
                                         RPHpara_AT_Qact1%dnC_inv%d0,   &
                                      indQ=[i,j,k],indDQ=ind3DQ,option=3)
          IF (cHAC) THEN
            CALL FinitDiff_AddMat_TO_dnMat(RPHpara_AT_Qact1_save%dnC,   &
                                         RPHpara_AT_Qact1%dnC%d0,       &
                                         indQ=[i,j,k],indDQ=ind3DQ,option=3)
            CALL FinitDiff_AddR_TO_dnS(RPHpara_AT_Qact1_save%dnLnN,     &
                                         RPHpara_AT_Qact1%dnLnN%d0,     &
                                         indQ=[i,j,k],indDQ=ind3DQ,option=3)
          END IF
        END DO

        CALL FinitDiff3_SymPerm_OF_dnVec(                               &
                                RPHpara_AT_Qact1_save%dnQopt,indQ=[i,j,k])
        CALL FinitDiff3_SymPerm_OF_dnMat(                                &
                               RPHpara_AT_Qact1_save%dnC_inv,indQ=[i,j,k])
        IF (cHAC) THEN
          CALL FinitDiff3_SymPerm_OF_dnMat(                             &
                                   RPHpara_AT_Qact1_save%dnC,indQ=[i,j,k])
          CALL FinitDiff3_SymPerm_OF_dnS(                               &
                                 RPHpara_AT_Qact1_save%dnLnN,indQ=[i,j,k])
        END IF
      END DO
      END DO
      END DO
    END IF

    CALL FinitDiff_Finalize_dnVec(RPHpara_AT_Qact1_save%dnQopt,RPHTransfo%step)
    CALL FinitDiff_Finalize_dnMat(RPHpara_AT_Qact1_save%dnC_inv,RPHTransfo%step)
    IF (cHAC) THEN
      CALL FinitDiff_Finalize_dnMat(RPHpara_AT_Qact1_save%dnC,RPHTransfo%step)
      CALL FinitDiff_Finalize_dnS(RPHpara_AT_Qact1_save%dnLnN,RPHTransfo%step)

      ! transformation in the ln derivatives
      DO i=1,RPHTransfo%nb_act1
        RPHpara_AT_Qact1_save%dnLnN%d1(i) =                             &
          RPHpara_AT_Qact1_save%dnLnN%d1(i)/RPHpara_AT_Qact1_save%dnLnN%d0
      END DO
      DO i=1,RPHTransfo%nb_act1
      DO j=1,RPHTransfo%nb_act1
        RPHpara_AT_Qact1_save%dnLnN%d2(i,j) =                           &
           RPHpara_AT_Qact1_save%dnLnN%d2(i,j)/RPHpara_AT_Qact1_save%dnLnN%d0 - &
           RPHpara_AT_Qact1_save%dnLnN%d1(i)*RPHpara_AT_Qact1_save%dnLnN%d1(j)
      END DO
      END DO

    END IF

!-----------------------------------------------------------
!-----------------------------------------------------------

    ! transfert RPHpara_AT_Qact1_save to save RPHpara_AT_Qact1
    CALL RPHpara1_AT_Qact1_TO_RPHpara2_AT_Qact1(RPHpara_AT_Qact1_save,  &
                                                RPHpara_AT_Qact1)
    CALL dealloc_RPHpara_AT_Qact1(RPHpara_AT_Qact1_save)
    CALL dealloc_NParray(Qact1,'Qact1',name_sub)

!-----------------------------------------------------------
!-----------------------------------------------------------
    IF (debug .OR. test) THEN
      write(out_unitp,11) RPHpara_AT_Qact1%RPHQact1(:),                 &
                          RPHpara_AT_Qact1%dnEHess%d0(:)*auTOcm_inv
 11   format(' frequencies : ',30f10.4)
      write(out_unitp,*) 'dnQopt'
      CALL Write_dnVec(RPHpara_AT_Qact1%dnQopt)
      write(out_unitp,*) 'dnC_inv'
      CALL Write_dnMat(RPHpara_AT_Qact1%dnC_inv)
      IF (cHAC) THEN
        write(out_unitp,*) 'dnC'
        CALL Write_dnMat(RPHpara_AT_Qact1%dnC)
        write(out_unitp,*) 'dnLnN'
        CALL Write_dnS(RPHpara_AT_Qact1%dnLnN)
      END IF

    END IF

    IF (debug) THEN
      write(out_unitp,*) 'END ',name_sub
    END IF
    CALL flush_perso(out_unitp)
!-----------------------------------------------------------

   END SUBROUTINE sub_dnfreq_v3


      SUBROUTINE sub_dnfreq_8p(dnQeq,dnC,dnLnN,dnEHess,dnHess,dnGrad,dnC_inv,&
                               pot0_corgrad,Qact,                      &
                               para_Tnum,mole,RPHTransfo,nderiv,test)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE

!----- for the CoordType and Tnum --------------------------------------
      TYPE (Tnum)    :: para_Tnum
      TYPE (CoordType) :: mole

      real (kind=Rkind), intent(inout) :: Qact(:)

!----- variables for the active and inactive namelists ----------------
      TYPE (Type_RPHTransfo)  :: RPHTransfo
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
      integer :: nderiv

!------ for the frequencies -------------------------------
        TYPE (Type_dnMat)     :: dnC,dnC_inv      ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnQeq            ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnEHess          ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnGrad           ! derivative with respect to Qact1
        TYPE (Type_dnMat)     :: dnHess           ! derivative with respect to Qact1
        TYPE (Type_dnS)       :: dnLnN            ! derivative with respect to Qact1

      real (kind=Rkind) :: pot0_corgrad,pot0_corgrad2


!----- pour les derivees ---------------------------------------------
      real (kind=Rkind) ::    step,step2,stepp,step24
      real (kind=Rkind) ::    d1


!----- for testing ---------------------------------------------------
      logical :: test


!----- working variables ---------------------------------------------
      integer           :: i,j,k,nb_inact21,nb_act1
      real (kind=Rkind) :: vi,vj

      real (kind=Rkind) ::  mat0(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat1(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec1(RPHTransfo%nb_inact21),vec0(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  mat2p(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2m(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat22p(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat22m(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  mat2_s(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2_s2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)



      real (kind=Rkind) ::  vec0p(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec0m(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec02p(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec02m(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  vec0_s(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec0_s2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  auTOcm_inv


!----- for debuging --------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='sub_dnfreq_8p'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
      write(out_unitp,*) 'BEGINNING ',name_sub
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        write(out_unitp,*) 'Qact',Qact
        write(out_unitp,*) 'purify_hess,eq_hess',                       &
                              RPHTransfo%purify_hess,RPHTransfo%eq_hess
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      step       = RPHTransfo%step
      step2      = step * HALF

      nb_inact21 = RPHTransfo%nb_inact21
      nb_act1    = RPHTransfo%nb_act1

      IF (RPHTransfo%step <= ZERO) THEN
        write(out_unitp,*) ' ERROR : RPHTransfo%step is < zero'
        STOP
      END IF


      CALL check_alloc_dnMat(dnC,'dnC',name_sub)
      CALL check_alloc_dnMat(dnC_inv,'dnC_inv',name_sub)
      CALL check_alloc_dnVec(dnQeq,'dnQeq',name_sub)
      CALL check_alloc_dnVec(dnEHess,'dnEHess',name_sub)
      CALL check_alloc_dnMat(dnHess,'dnHess',name_sub)
      CALL check_alloc_dnVec(dnGrad,'dnGrad',name_sub)
      CALL check_alloc_dnS(dnLnN,'dnLnN',name_sub)

      IF (nderiv == 0) THEN
        CALL sub_freq2_RPH(dnEHess%d0,dnC%d0,dnC_inv%d0,        &
                       dnLnN%d0,dnHess%d0,dnQeq%d0,                     &
                       dnGrad%d0,pot0_corgrad,                          &
                       Qact,para_Tnum,mole,RPHTransfo)

        IF (debug) THEN
          write(out_unitp,*) 'dnQeq%d0',dnQeq%d0(:)
          write(out_unitp,*) 'freq',dnEHess%d0(:)*auTOcm_inv
          write(out_unitp,*) 'dnC'
          CALL Write_dnMat(dnC)
          write(out_unitp,*) 'dnHess'
          CALL Write_dnMat(dnHess)
          write(out_unitp,*) 'END ',name_sub
        END IF
        RETURN
      END IF


!-----------------------------------------------------------------
!----- frequencies calculation at Qact --------------------------
!-----------------------------------------------------------------

      CALL sub_freq2_RPH(dnEHess%d0,dnC%d0,dnC_inv%d0,                  &
                         dnLnN%d0,dnHess%d0,dnQeq%d0,                   &
                         dnGrad%d0,pot0_corgrad,                        &
                         Qact,para_Tnum,mole,RPHTransfo)

!-----------------------------------------------------------------
!----- end frequencies calculation at Qact -----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d/Qqi et d2/dQi2 of frequencies ---------------------------
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1

        vi = Qact(i)

!       -- frequencies calculation at Qact(i)+step -------------
        Qact(i) = vi + step

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2p   = mat2-dnC_inv%d0
        vec0p   = vec0-dnQeq%d0


!       -- frequencies calculation at Qact(i)-step -------------
        Qact(i) = vi - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2m   = mat2-dnC_inv%d0
        vec0m   = vec0-dnQeq%d0


!       -- frequencies calculation at Qact(i)+step -------------
        Qact(i) = vi + step2

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat22p   = mat2-dnC_inv%d0
        vec02p   = vec0-dnQeq%d0


!       -- frequencies calculation at Qact(i)-step -------------
        Qact(i) = vi - step2

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat22m   = mat2-dnC_inv%d0
        vec02m   = vec0-dnQeq%d0



        dnC_inv%d1(:,:,i)   = (EIGHT*(mat22p-mat22m)-(mat2p-mat2m))/(SIX*step)
        dnC_inv%d2(:,:,i,i) = (16._Rkind*(mat22p+mat22m)-(mat2p+mat2m)) / (THREE*step*step)

        dnQeq%d1(:,i)     = (EIGHT*(vec02p-vec02m)-(vec0p-vec0m))/(SIX*step)
        dnQeq%d2(:,i,i)   = (16._Rkind*(vec02p+vec02m)-(vec0p+vec0m)) / (THREE*step*step)

        Qact(i) = vi
      END DO


!-----------------------------------------------------------------
!----- end d/Qqi and d2/dQi2 of frequencies ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d2/dQidQj of frequencies (4 points) -----------------------
!      d2/dQidQj = ( v(Qi+,Qj+)+v(Qi-,Qj-)-v(Qi-,Qj+)-v(Qi+,Qj-) )/(4*s*s)
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1

        vi = Qact(i)
        vj = Qact(j)


!       -- frequencies calculation at Qact(i)+step Qact(j)+step
        Qact(i) = vi + step
        Qact(j) = vj + step
        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s   = mat2
        vec0_s   = vec0



!       -- frequencies calculation at Qact(i)-step Qact(j)-step
        Qact(i) = vi - step
        Qact(j) = vj - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s   = mat2_s + mat2
        vec0_s   = vec0_s + vec0


!       -- frequencies calculation at Qact(i)-step Qact(j)+step
        Qact(i) = vi - step
        Qact(j) = vj + step

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s   = mat2_s - mat2
        vec0_s   = vec0_s - vec0

!       -- frequencies calculation at Qact(i)+step Qact(j)-step
        Qact(i) = vi + step
        Qact(j) = vj - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s   = mat2_s - mat2
        vec0_s   = vec0_s - vec0


!       -- frequencies calculation at Qact(i)+step Qact(j)+step
        Qact(i) = vi + step2
        Qact(j) = vj + step2
        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s2   = mat2
        vec0_s2   = vec0



!       -- frequencies calculation at Qact(i)-step Qact(j)-step
        Qact(i) = vi - step2
        Qact(j) = vj - step2

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s2   = mat2_s2 + mat2
        vec0_s2   = vec0_s2 + vec0


!       -- frequencies calculation at Qact(i)-step Qact(j)+step
        Qact(i) = vi - step2
        Qact(j) = vj + step2

        CALL sub_freq2_RPH(vec1,mat1,mat2,                      &
                       d1,mat0,vec0,                                    &
                       vec2,pot0_corgrad2,                              &
                       Qact,para_Tnum,mole,RPHTransfo)

        mat2_s2   = mat2_s2 - mat2
        vec0_s2   = vec0_s2 - vec0

!       -- frequencies calculation at Qact(i)+step Qact(j)-step
        Qact(i) = vi + step2
        Qact(j) = vj - step2

        CALL sub_freq2_RPH(vec1,mat1,mat2, d1,mat0,vec0,vec2,           &
                           pot0_corgrad2,                               &
                           Qact,para_Tnum,mole,RPHTransfo)

        mat2_s2   = mat2_s2 - mat2
        vec0_s2   = vec0_s2 - vec0


!       -- d2/dQi/dQj -----------------------------------------

        dnC_inv%d2(:,:,i,j) = (16._Rkind*mat2_s2 - mat2_s)/(step*step*TWELVE)
        dnQeq%d2(:,i,j)     = (16._Rkind*vec0_s2 - vec0_s)/(step*step*TWELVE)

        dnC_inv%d2(:,:,j,i) = dnC_inv%d2(:,:,i,j)
        dnQeq%d2(:,j,i)     = dnQeq%d2(:,i,j)


        Qact(i) = vi
        Qact(j) = vj
      END DO
      END DO
!-----------------------------------------------------------------
!----- end d2/dQidQj of frequencies ------------------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------

       IF (debug .OR. test) THEN
         write(out_unitp,11)                         &
                  Qact(1:RPHTransfo%nb_act1),dnEHess%d0(:)*auTOcm_inv
 11      format(' frequencies : ',30f10.4)
         write(out_unitp,*) 'dnQeq'
         CALL Write_dnVec(dnQeq)
         write(out_unitp,*) 'dnC_inv'
         CALL Write_dnMat(dnC_inv)
       END IF

       IF (debug) THEN
         write(out_unitp,*) 'END ',name_sub
       END IF
      CALL flush_perso(out_unitp)
!-----------------------------------------------------------

      END SUBROUTINE sub_dnfreq_8p
      SUBROUTINE sub_dnfreq_8p_v2(RPHpara_AT_Qact1,pot0_corgrad,        &
                                  para_Tnum,mole,RPHTransfo,nderiv,test)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      USE CurviRPH_mod
      IMPLICIT NONE


!----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      TYPE (Tnum)                                 :: para_Tnum
      TYPE (CoordType),             intent(inout) :: mole

!----- variables for the active and inactive namelists ----------------
      TYPE (Type_RPHTransfo), intent(inout)  :: RPHTransfo
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
      integer, intent(in) :: nderiv
!----- for testing ---------------------------------------------------
      logical, intent(in) :: test


!------ for the frequencies -------------------------------
        TYPE (Type_dnMat)     :: dnC,dnC_inv      ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnQeq            ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnEHess          ! derivative with respect to Qact1
        TYPE (Type_dnVec)     :: dnGrad           ! derivative with respect to Qact1
        TYPE (Type_dnMat)     :: dnHess           ! derivative with respect to Qact1
        TYPE (Type_dnS)       :: dnLnN            ! derivative with respect to Qact1

      real (kind=Rkind) :: pot0_corgrad,pot0_corgrad2
      TYPE (Type_RPHpara_AT_Qact1)  :: RPHpara_AT_Qact1_save


!----- pour les derivees ---------------------------------------------
      real (kind=Rkind) ::    step,step2,stepp,step24
      real (kind=Rkind) ::    d1

!----- working variables ---------------------------------------------
      integer           :: i,j,k,nb_inact21,nb_act1
      real (kind=Rkind) :: vi,vj

      real (kind=Rkind) ::  mat0(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat1(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec1(RPHTransfo%nb_inact21),vec0(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  mat2p(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2m(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat22p(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat22m(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  mat2_s(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2_s2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)



      real (kind=Rkind) ::  vec0p(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec0m(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec02p(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec02m(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  vec0_s(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec0_s2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  auTOcm_inv
      real (kind=Rkind) ::  wd1,wd2,wdd1,wdd2

!----- for debuging --------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='sub_dnfreq_8p_v2'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
      write(out_unitp,*) 'BEGINNING ',name_sub
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      step       = RPHTransfo%step
      step2      = step * HALF

      nb_inact21 = RPHTransfo%nb_inact21
      nb_act1    = RPHTransfo%nb_act1

      IF (RPHTransfo%step <= ZERO) THEN
        write(out_unitp,*) ' ERROR : RPHTransfo%step is < zero'
        STOP
      END IF


      IF (nderiv == 0) THEN
        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        IF (debug) THEN
          write(out_unitp,*) 'dnQeq%d0',dnQeq%d0(:)
          write(out_unitp,*) 'freq',dnEHess%d0(:)*auTOcm_inv
          write(out_unitp,*) 'dnC'
          CALL Write_dnMat(dnC)
          write(out_unitp,*) 'dnHess'
          CALL Write_dnMat(dnHess)
          write(out_unitp,*) 'END ',name_sub
        END IF
        RETURN
      END IF

!-----------------------------------------------------------------
!----- frequencies calculation at Qact ---------------------------
!-----------------------------------------------------------------
      CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,              &
                            para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

      ! save RPHpara_AT_Qact1 => RPHpara_AT_Qact1_save (for the numerical derivatives)
      CALL RPHpara1_AT_Qact1_TO_RPHpara2_AT_Qact1(RPHpara_AT_Qact1,     &
                                                  RPHpara_AT_Qact1_save)

!-----------------------------------------------------------------
!----- end frequencies calculation at Qact -----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d/Qqi et d2/dQi2 of frequencies ---------------------------
!-----------------------------------------------------------------
      wd1  = ONE/(SIX*step)
      wd2  = EIGHT/(SIX*step)
      wdd1 = ONE/(THREE*step*step)
      wdd2 = 16._Rkind/(THREE*step*step)

      DO i=1,RPHTransfo%nb_act1

        vi = RPHpara_AT_Qact1%RPHQact1(i)

        !-- frequencies calculation at Qact(i)+step -------------
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2p = RPHpara_AT_Qact1%dnC_inv%d0 - RPHpara_AT_Qact1_save%dnC_inv%d0
        vec0p = RPHpara_AT_Qact1%dnQopt%d0  - RPHpara_AT_Qact1_save%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec0p,-wd1, RPHpara_AT_Qact1_save%dnQopt,[i],  nderiv)
        CALL Vec_wADDTO_dnVec2_ider(vec0p,-wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,i],nderiv)

        CALL Mat_wADDTO_dnMat2_ider(mat2p,-wd1, RPHpara_AT_Qact1_save%dnC_inv,[i],  nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2p,-wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,i],nderiv)

        !-- frequencies calculation at Qact(i)-step -------------
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2m = RPHpara_AT_Qact1%dnC_inv%d0 - RPHpara_AT_Qact1_save%dnC_inv%d0
        vec0m = RPHpara_AT_Qact1%dnQopt%d0  - RPHpara_AT_Qact1_save%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec0m, wd1, RPHpara_AT_Qact1_save%dnQopt,[i],  nderiv)
        CALL Vec_wADDTO_dnVec2_ider(vec0m,-wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,i],nderiv)

        CALL Mat_wADDTO_dnMat2_ider(mat2m, wd1, RPHpara_AT_Qact1_save%dnC_inv,[i],  nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2m,-wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,i],nderiv)

        !-- frequencies calculation at Qact(i)+step -------------
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat22p = RPHpara_AT_Qact1%dnC_inv%d0 - RPHpara_AT_Qact1_save%dnC_inv%d0
        vec02p = RPHpara_AT_Qact1%dnQopt%d0  - RPHpara_AT_Qact1_save%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec02p, wd2, RPHpara_AT_Qact1_save%dnQopt,[i],  nderiv)
        CALL Vec_wADDTO_dnVec2_ider(vec02p, wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,i],nderiv)

        CALL Mat_wADDTO_dnMat2_ider(mat22p, wd2, RPHpara_AT_Qact1_save%dnC_inv,[i],  nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat22p, wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,i],nderiv)

        !-- frequencies calculation at Qact(i)-step -------------
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat22m = RPHpara_AT_Qact1%dnC_inv%d0 - RPHpara_AT_Qact1_save%dnC_inv%d0
        vec02m = RPHpara_AT_Qact1%dnQopt%d0  - RPHpara_AT_Qact1_save%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec02m,-wd2, RPHpara_AT_Qact1_save%dnQopt,[i],  nderiv)
        CALL Vec_wADDTO_dnVec2_ider(vec02m, wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,i],nderiv)

        CALL Mat_wADDTO_dnMat2_ider(mat22m,-wd2, RPHpara_AT_Qact1_save%dnC_inv,[i],  nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat22m, wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,i],nderiv)

        !RPHpara_AT_Qact1_save%dnC_inv%d1(:,:,i)   = (EIGHT*(mat22p-mat22m)-(mat2p-mat2m))/(SIX*step)
        !RPHpara_AT_Qact1_save%dnC_inv%d2(:,:,i,i) = (16._Rkind*(mat22p+mat22m)-(mat2p+mat2m)) / (THREE*step*step)

        !RPHpara_AT_Qact1_save%dnQopt%d1(:,i)     = (EIGHT*(vec02p-vec02m)-(vec0p-vec0m))/(SIX*step)
        !RPHpara_AT_Qact1_save%dnQopt%d2(:,i,i)   = (16._Rkind*(vec02p+vec02m)-(vec0p+vec0m)) / (THREE*step*step)

        RPHpara_AT_Qact1%RPHQact1(i) = vi
      END DO
!-----------------------------------------------------------------
!----- end d/Qqi and d2/dQi2 of frequencies ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d2/dQidQj of frequencies (4 points) -----------------------
!      d2/dQidQj = ( v(Qi+,Qj+)+v(Qi-,Qj-)-v(Qi-,Qj+)-v(Qi+,Qj-) )/(4*s*s)
!-----------------------------------------------------------------
      wdd1 = ONE/(step*step*TWELVE)
      wdd2 = 16._Rkind/(step*step*TWELVE)

      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1


        vi = RPHpara_AT_Qact1%RPHQact1(i)
        vj = RPHpara_AT_Qact1%RPHQact1(j)

        !-- frequencies calculation at Qact(i)+step Qact(j)+step
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step
        RPHpara_AT_Qact1%RPHQact1(j) = vj + step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s = RPHpara_AT_Qact1%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec0_s, wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s, wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)-step Qact(j)-step
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step
        RPHpara_AT_Qact1%RPHQact1(j) = vj - step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s   = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s   = RPHpara_AT_Qact1%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec0_s, wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s, wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)-step Qact(j)+step
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step
        RPHpara_AT_Qact1%RPHQact1(j) = vj + step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s   = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s   = RPHpara_AT_Qact1%dnQopt%d0

        CALL Vec_wADDTO_dnVec2_ider(vec0_s,-wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s,-wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)+step Qact(j)-step
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step
        RPHpara_AT_Qact1%RPHQact1(j) = vj - step

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s   = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s   = RPHpara_AT_Qact1%dnQopt%d0
        CALL Vec_wADDTO_dnVec2_ider(vec0_s,-wdd1,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s,-wdd1,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)+step Qact(j)+step
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step2
        RPHpara_AT_Qact1%RPHQact1(j) = vj + step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s2 = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s2 = RPHpara_AT_Qact1%dnQopt%d0
        CALL Vec_wADDTO_dnVec2_ider(vec0_s, wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s, wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)-step Qact(j)-step
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step2
        RPHpara_AT_Qact1%RPHQact1(j) = vj - step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s2 = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s2 = RPHpara_AT_Qact1%dnQopt%d0
        CALL Vec_wADDTO_dnVec2_ider(vec0_s, wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s, wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)-step Qact(j)+step
        RPHpara_AT_Qact1%RPHQact1(i) = vi - step2
        RPHpara_AT_Qact1%RPHQact1(j) = vj + step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s2 = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s2 = RPHpara_AT_Qact1%dnQopt%d0
        CALL Vec_wADDTO_dnVec2_ider(vec0_s,-wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s,-wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

        !-- frequencies calculation at Qact(i)+step Qact(j)-step
        RPHpara_AT_Qact1%RPHQact1(i) = vi + step2
        RPHpara_AT_Qact1%RPHQact1(j) = vj - step2

        CALL sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,            &
                              para_Tnum,mole,RPHTransfo,cHAC=.FALSE.)

        mat2_s2 = RPHpara_AT_Qact1%dnC_inv%d0
        vec0_s2 = RPHpara_AT_Qact1%dnQopt%d0
        CALL Vec_wADDTO_dnVec2_ider(vec0_s,-wdd2,RPHpara_AT_Qact1_save%dnQopt,[i,j],nderiv)
        CALL Mat_wADDTO_dnMat2_ider(mat2_s,-wdd2,RPHpara_AT_Qact1_save%dnC_inv,[i,j],nderiv)

!       -- d2/dQi/dQj -----------------------------------------

        !RPHpara_AT_Qact1_save%dnC_inv%d2(:,:,i,j) = (16._Rkind*mat2_s2 - mat2_s)/(step*step*TWELVE)
        !RPHpara_AT_Qact1_save%dnQopt%d2(:,i,j)    = (16._Rkind*vec0_s2 - vec0_s)/(step*step*TWELVE)

        RPHpara_AT_Qact1_save%dnC_inv%d2(:,:,j,i) = dnC_inv%d2(:,:,i,j)
        RPHpara_AT_Qact1_save%dnQopt%d2(:,j,i)    = dnQeq%d2(:,i,j)


        RPHpara_AT_Qact1%RPHQact1(i) = vi
        RPHpara_AT_Qact1%RPHQact1(j) = vj
      END DO
      END DO
!-----------------------------------------------------------------
!----- end d2/dQidQj of frequencies ------------------------------
!-----------------------------------------------------------------





      ! transfert RPHpara_AT_Qact1_save to save RPHpara_AT_Qact1
      CALL RPHpara1_AT_Qact1_TO_RPHpara2_AT_Qact1(RPHpara_AT_Qact1_save,&
                                                  RPHpara_AT_Qact1)
      CALL dealloc_RPHpara_AT_Qact1(RPHpara_AT_Qact1_save)

       IF (debug .OR. test) THEN
         write(out_unitp,11) RPHpara_AT_Qact1%RPHQact1(:),                 &
                             RPHpara_AT_Qact1%dnEHess%d0(:)*auTOcm_inv
 11      format(' frequencies : ',30f10.4)
         write(out_unitp,*) 'dnQopt'
         CALL Write_dnVec(RPHpara_AT_Qact1%dnQopt)
         write(out_unitp,*) 'dnC_inv'
         CALL Write_dnMat(RPHpara_AT_Qact1%dnC_inv)
       END IF

       IF (debug) THEN
         write(out_unitp,*) 'END ',name_sub
       END IF
      CALL flush_perso(out_unitp)
!-----------------------------------------------------------
!STOP 'coucou sub_dnfreq_8p_v2'

      END SUBROUTINE sub_dnfreq_8p_v2

      SUBROUTINE sub_dnfreq_4p(dnQeq,dnC,dnLnN,dnEHess,dnHess,dnGrad,dnC_inv,&
                               pot0_corgrad,Qact,                       &
                               para_Tnum,mole,RPHTransfo,nderiv,test)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE

!----- for the CoordType and Tnum --------------------------------------
      TYPE (Tnum)             :: para_Tnum
      TYPE (CoordType)          :: mole
      TYPE (Type_RPHTransfo)  :: RPHTransfo

      real (kind=Rkind), intent(inout) :: Qact(:)

!----- variables for the active and inactive namelists ----------------

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
      integer :: nderiv

!------ for the frequencies -------------------------------
      TYPE (Type_dnMat)     :: dnC,dnC_inv      ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnQeq            ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnEHess          ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnGrad           ! derivative with respect to Qact1
      TYPE (Type_dnMat)     :: dnHess           ! derivative with respect to Qact1
      TYPE (Type_dnS)       :: dnLnN            ! derivative with respect to Qact1

      real (kind=Rkind) :: pot0_corgrad,pot0_corgrad2

      real (kind=Rkind)  :: Qact1(RPHTransfo%nb_act1)


!----- pour les derivees ---------------------------------------------
      real (kind=Rkind) ::    step,step2,stepp,step24
      real (kind=Rkind) ::    d1


!----- for testing ---------------------------------------------------
      logical :: test


!----- working variables ---------------------------------------------
      integer           :: i,j,k,nb_inact21,nb_act1
      real (kind=Rkind) :: vi,vj

      real (kind=Rkind) ::  mat0(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat1(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec1(RPHTransfo%nb_inact21),vec0(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  auTOcm_inv

!----- for debuging --------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='sub_dnfreq_4p'
      logical, parameter :: debug = .FALSE.
!     logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        write(out_unitp,*) 'Qact',Qact
        write(out_unitp,*) 'purify_hess,eq_hess',                       &
                              RPHTransfo%purify_hess,RPHTransfo%eq_hess
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      step     = RPHTransfo%step
      step2    = ONE/(step*step)
      step24   = step2*HALF*HALF
      stepp    = ONE/(step+step)

      nb_inact21 = RPHTransfo%nb_inact21
      nb_act1    = RPHTransfo%nb_act1

      IF (RPHTransfo%step <= ZERO) THEN
        write(out_unitp,*) ' ERROR : RPHTransfo%step is <= to zero'
        STOP
      END IF


      CALL check_alloc_dnMat(dnC,'dnC',name_sub)
      CALL check_alloc_dnMat(dnC_inv,'dnC_inv',name_sub)
      CALL check_alloc_dnVec(dnQeq,'dnQeq',name_sub)
      CALL check_alloc_dnVec(dnEHess,'dnEHess',name_sub)
      CALL check_alloc_dnMat(dnHess,'dnHess',name_sub)
      CALL check_alloc_dnVec(dnGrad,'dnGrad',name_sub)
      CALL check_alloc_dnS(dnLnN,'dnLnN',name_sub)


      IF (nderiv == 0) THEN
        CALL sub_freq2_RPH(dnEHess%d0,dnC%d0,dnC_inv%d0,                &
                           dnLnN%d0,dnHess%d0,dnQeq%d0,                 &
                           dnGrad%d0,pot0_corgrad,                      &
                           Qact,para_Tnum,mole,RPHTransfo)

        IF (debug) THEN
          write(out_unitp,*) 'dnQeq%d0',dnQeq%d0(:)
          write(out_unitp,*) 'freq',dnEHess%d0(:)*auTOcm_inv
          write(out_unitp,*) 'dnC'
          CALL Write_dnMat(dnC)
          write(out_unitp,*) 'dnHess'
          CALL Write_dnMat(dnHess)
          write(out_unitp,*) 'END ',name_sub
        END IF
        RETURN
      END IF


!-----------------------------------------------------------------
!----- frequencies calculation at Qact --------------------------
!-----------------------------------------------------------------

      CALL sub_freq2_RPH(dnEHess%d0,dnC%d0,dnC_inv%d0,                  &
                         dnLnN%d0,dnHess%d0,dnQeq%d0,dnGrad%d0,         &
                         pot0_corgrad,Qact,para_Tnum,mole,RPHTransfo)

!-----------------------------------------------------------------
!----- end frequencies calculation at Qact ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d/Qqi et d2/dQi2 of frequencies ---------------------------
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1

        vi = Qact(i)

!       -- frequencies calculation at Qact(i)+step -------------
        Qact(i) = vi + step

        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d1(:,:,i)   = mat2
        dnC_inv%d2(:,:,i,i) = mat2

        dnLnN%d1(i)         = d1
        dnLnN%d2(i,i)       = d1

        dnC%d1(:,:,i)       = mat1(:,:)
        dnC%d2(:,:,i,i)     = mat1(:,:)

        dnHess%d1(:,:,i)    = mat0(:,:)
        dnHess%d2(:,:,i,i)  = mat0(:,:)

        dnQeq%d1(:,i)       = vec0(:)
        dnQeq%d2(:,i,i)     = vec0(:)

!       -- frequencies calculation at Qact(i)-step -------------
        Qact(i) = vi - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d1(:,:,i)   = (dnC_inv%d1(:,:,i)   - mat2)*stepp
        dnC_inv%d2(:,:,i,i) = (dnC_inv%d2(:,:,i,i) + mat2 -TWO*dnC_inv%d0)*step2

        dnLnN%d1(i)        = (dnLnN%d1(i)   - d1)*stepp
        dnLnN%d2(i,i)      = (dnLnN%d2(i,i) + d1 -dnLnN%d0-dnLnN%d0)*step2

        dnC%d1(:,:,i)      = ( dnC%d1(:,:,i) -  mat1(:,:) ) * stepp
        dnC%d2(:,:,i,i)    = (dnC%d2(:,:,i,i)+mat1(:,:)-dnC%d0(:,:)-dnC%d0(:,:))*step2

        dnHess%d1(:,:,i)   = ( dnHess%d1(:,:,i) -  mat0(:,:) ) * stepp
        dnHess%d2(:,:,i,i) = (dnHess%d2(:,:,i,i)+mat0(:,:)-               &
                                   dnHess%d0(:,:)-dnHess%d0(:,:))*step2

        dnQeq%d1(:,i)      = ( dnQeq%d1(:,i) - vec0(:) ) * stepp
        dnQeq%d2(:,i,i)    = (dnQeq%d2(:,i,i)+vec0(:)-dnQeq%d0(:)-dnQeq%d0(:))*step2


        Qact(i) = vi
      END DO


!-----------------------------------------------------------------
!----- end d/Qqi and d2/dQi2 of frequencies ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d2/dQidQj of frequencies (4 points) -----------------------
!      d2/dQidQj = ( v(Qi+,Qj+)+v(Qi-,Qj-)-v(Qi-,Qj+)-v(Qi+,Qj-) )/(4*s*s)
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1

        vi = Qact(i)
        vj = Qact(j)


!       -- frequencies calculation at Qact(i)+step Qact(j)+step
        Qact(i) = vi + step
        Qact(j) = vj + step
        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = mat2
        dnLnN%d2(i,j)       = d1
        dnC%d2(:,:,i,j)     = mat1(:,:)
        dnHess%d2(:,:,i,j)  = mat0(:,:)
        dnQeq%d2(:,i,j)     = vec0(:)

!       -- frequencies calculation at Qact(i)-step Qact(j)-step
        Qact(i) = vi - step
        Qact(j) = vj - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) + mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       + d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     + mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  + mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     + vec0

!       -- frequencies calculation at Qact(i)-step Qact(j)+step
        Qact(i) = vi - step
        Qact(j) = vj + step

        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) - mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       - d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     - mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  - mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     - vec0

!       -- frequencies calculation at Qact(i)+step Qact(j)-step
        Qact(i) = vi + step
        Qact(j) = vj - step

        CALL sub_freq2_RPH(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) - mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       - d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     - mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  - mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     - vec0


!       -- d2/dQi/dQj -----------------------------------------

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) * step24
        dnC_inv%d2(:,:,j,i) = dnC_inv%d2(:,:,i,j)

        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       * step24
        dnLnN%d2(j,i)       = dnLnN%d2(i,j)

        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     * step24
        dnC%d2(:,:,j,i)     = dnC%d2(:,:,i,j)

        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  * step24
        dnHess%d2(:,:,j,i)  = dnHess%d2(:,:,i,j)

        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     * step24
        dnQeq%d2(:,j,i)     = dnQeq%d2(:,i,j)


        Qact(i) = vi
        Qact(j) = vj
      END DO
      END DO
!-----------------------------------------------------------------
!----- end d2/dQidQj of frequencies ------------------------------
!-----------------------------------------------------------------


      DO i=1,RPHTransfo%nb_act1
        dnLnN%d1(i) = dnLnN%d1(i)/dnLnN%d0
      END DO
      DO i=1,RPHTransfo%nb_act1
      DO j=1,RPHTransfo%nb_act1
        dnLnN%d2(i,j) = dnLnN%d2(i,j)/dnLnN%d0 - dnLnN%d1(i)*dnLnN%d1(j)
      END DO
      END DO

!-----------------------------------------------------------
      IF (print_level >= 1) THEN
        IF (maxval(abs(dnEHess%d0)) > 9000._Rkind) THEN
          write(out_unitp,*) ' frequencies : ',Qact(1:RPHTransfo%nb_act1), &
                                                dnEHess%d0(:)*auTOcm_inv
        ELSE
          write(out_unitp,11) Qact(1:RPHTransfo%nb_act1),               &
                                                dnEHess%d0(:)*auTOcm_inv
 11       format(' frequencies : ',30f10.4)
        END IF
      END IF
       IF (debug .OR. test) THEN
         write(out_unitp,*) 'dnQeq'
         CALL Write_dnVec(dnQeq)
         write(out_unitp,*) 'dnHess'
         CALL Write_dnMat(dnHess)
         write(out_unitp,*) 'dnC_inv'
         CALL Write_dnMat(dnC_inv)
       END IF

       IF (debug) THEN
         write(out_unitp,*) 'END ',name_sub
       END IF
      CALL flush_perso(out_unitp)
!-----------------------------------------------------------

      END SUBROUTINE sub_dnfreq_4p
!=============================================================
!
!     frequency calculations along Qact
!
!=============================================================
      SUBROUTINE sub_freq2_RPH(d0ehess,d0c,d0c_inv,                     &
                               norme,d0hess,d0Qeq,d0g,pot0_corgrad,     &
                               Qact,para_Tnum,mole,RPHTransfo)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE

      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Tnum)        :: para_Tnum
      TYPE (CoordType)   :: mole

      real (kind=Rkind), intent(inout) :: Qact(:)

      real (kind=Rkind)  :: rho,vep

!----- variables for the active and inactive namelists ----------------
      TYPE (Type_RPHTransfo)  :: RPHTransfo

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------



!------ pour les frequences -------------------------------

       real (kind=Rkind) :: d0ehess(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0ek(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0g(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0Qeq(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0hess(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0c(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0c_inv(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: norme

       real (kind=Rkind) :: pot0_corgrad


!----- working variables ---------------------------------------------
!----- variables pour les derivees -----------------------------------
      logical       :: deriv,num
      integer       :: i,j,i_Qdyn,nderiv
      logical       :: special

      integer       :: nb_act1,nb_inact21
      real (kind=Rkind) :: Qdyn(mole%nb_var)


      real (kind=Rkind) :: a,d0req
      real (kind=Rkind) :: auTOcm_inv

      real (kind=Rkind), allocatable ::                                 &
        d1req(:),d2req(:,:),d3req(:,:,:),                               &
        d1g(:,:),d2g(:,:,:),                                            &
        d0h(:,:),d1hess(:,:,:),d2hess(:,:,:,:),                         &
        d0k(:,:),                                                       &
        d0hess_inv(:,:),trav1(:),NonDiag_Scaling(:)

      TYPE(Type_dnMat) :: dnGG

!----- for debuging --------------------------------------------------
       integer :: err_mem,memory
       character (len=*), parameter :: name_sub = 'sub_freq2_RPH'
       logical, parameter :: debug = .FALSE.
       !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
       IF (debug) THEN
         write(out_unitp,*) 'BEGINNING ',name_sub
         write(out_unitp,*) 'Qact',Qact
         write(out_unitp,*) 'RPHTransfo%step',RPHTransfo%step
         CALL flush_perso(out_unitp)
       END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      nb_act1    = RPHTransfo%nb_act1
      nb_inact21 = RPHTransfo%nb_inact21
      IF (.NOT. associated(RPHTransfo%C_ini)) THEN
        CALL alloc_array(RPHTransfo%C_ini,(/nb_inact21,nb_inact21/),    &
                          "RPHTransfo%C_ini",name_sub)
        RPHTransfo%C_ini(:,:) = ZERO
      END IF
      IF (debug) THEN
        write(out_unitp,*) 'RPHTransfo%C_ini'
        CALL Write_Mat(RPHTransfo%C_ini,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF

!-----------------------------------------------------------------
!--------- Qact => Qdyn ------------------------------------------
! we need Qdyn because, we calculate, the hessian, grandient with Qdyn coord
!-----------------------------------------------------------------
       CALL Qact_TO_Qdyn_FROM_ActiveTransfo(Qact,Qdyn,mole%ActiveTransfo)
       IF (debug) write(out_unitp,*) 'Qdyn',Qdyn

!-----------------------------------------------------------------


!-----------------------------------------------------------------
!-----------------------------------------------------------------
!----- d0Qeq, d0g and d0h at Qdyn --------------------------------
!      Qdyn and Qact are also modified
!-----------------------------------------------------------------
      nderiv = 0
      deriv  = .FALSE.

      CALL alloc_NParray(d1req,(/ nb_act1 /),"d1req",name_sub)
      CALL alloc_NParray(d2req,(/ nb_act1,nb_act1 /),"d2req",name_sub)
      CALL alloc_NParray(d3req,(/ nb_act1,nb_act1,nb_act1 /),"d3req",name_sub)

      DO i=1,nb_inact21

        i_Qdyn = mole%ActiveTransfo%list_QactTOQdyn(nb_act1+i)

        CALL d0d1d2d3_Qeq(i_Qdyn,d0req,d1req,d2req,d3req,Qdyn,mole,nderiv)

        IF (debug) write(out_unitp,*) 'i_Qdyn,i,d0req',i_Qdyn,i,d0req
        CALL flush_perso(out_unitp)
        d0Qeq(i)             = d0req
        Qdyn(i_Qdyn)         = d0req
        Qact(nb_act1+i)      = d0req

      END DO

      CALL dealloc_NParray(d1req,"d1req",name_sub)
      CALL dealloc_NParray(d2req,"d2req",name_sub)
      CALL dealloc_NParray(d3req,"d3req",name_sub)

      !------ The gradient ----------------------------------
      CALL alloc_NParray(d1g,(/ nb_inact21,nb_act1 /),"d1g",name_sub)
      CALL alloc_NParray(d2g,(/ nb_inact21,nb_act1,nb_act1 /),"d2g",name_sub)

      CALL d0d1d2_g(d0g,d1g,d2g,Qdyn,mole,.FALSE.,.FALSE.,RPHTransfo%step)

      CALL dealloc_NParray(d1g,"d1g",name_sub)
      CALL dealloc_NParray(d2g,"d2g",name_sub)

      !------ The hessian ----------------------------------
      CALL alloc_NParray(d1hess,(/ nb_inact21,nb_inact21,nb_act1 /),    &
                        "d1hess",name_sub)
      CALL alloc_NParray(d2hess,(/nb_inact21,nb_inact21,nb_act1,nb_act1/),&
                        "d2hess",name_sub)

      CALL d0d1d2_h(d0hess,d1hess,d2hess,Qdyn,mole,.FALSE.,.FALSE.,RPHTransfo%step)

      CALL dealloc_NParray(d1hess,"d1hess",name_sub)
      CALL dealloc_NParray(d2hess,"d2hess",name_sub)


      !-----------------------------------------------------------------
      !- the gardient is taken into account for d0Qeq -------------
      CALL alloc_NParray(d0h,(/nb_inact21,nb_inact21/),"d0h",name_sub)
      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%gradTOpot0) THEN
        CALL alloc_NParray(d0hess_inv,(/nb_inact21,nb_inact21/),"d0hess_inv",name_sub)
        CALL alloc_NParray(trav1,(/nb_inact21/),"trav1",name_sub)

        CALL inv_m1_TO_m2(d0h,d0hess_inv,nb_inact21,0,ZERO) ! not SVD
        trav1(:)     = matmul(d0hess_inv,d0g)
        pot0_corgrad = -HALF*dot_product(d0g,trav1)
        d0Qeq(:)     = d0Qeq(:) - trav1(:)
        d0g(:)       = ZERO

        !-- merge d0Qeq(:) with Qact(:)
        CALL Qinact2n_TO_Qact_FROM_ActiveTransfo(d0Qeq,Qact,mole%ActiveTransfo)

        CALL dealloc_NParray(d0hess_inv,"d0hess_inv",name_sub)
        CALL dealloc_NParray(trav1,"trav1",name_sub)
      ELSE
        pot0_corgrad = ZERO
      END IF

      !-----------------------------------------------------------------
      !------ The kinetic part -------------------------------
      CALL alloc_NParray(d0k,(/nb_inact21,nb_inact21/),"d0k",name_sub)

      CALL alloc_dnSVM(dnGG,mole%ndimG,mole%ndimG,mole%nb_act,0)

      CALL get_dng_dnGG(Qact,para_Tnum,mole,dnGG=dnGG,nderiv=0)

      d0k(:,:) = dnGG%d0(nb_act1+1:nb_act1+nb_inact21,                  &
                         nb_act1+1:nb_act1+nb_inact21)

      CALL dealloc_dnSVM(dnGG)


!-----------------------------------------------------------------
!     --- frequencies and normal modes calculation ....
      IF (debug) THEN
        write(out_unitp,*) 'd0hess,d0k'
        CALL Write_Mat(d0hess,out_unitp,4)
        CALL Write_Mat(d0k,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF

      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%purify_hess .OR. RPHTransfo%eq_hess) THEN
        CALL H0_symmetrization(d0h,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        CALL H0_symmetrization(d0k,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        IF (debug) THEN
          write(out_unitp,*) 'sym : d0hess,d0k'
          CALL Write_Mat(d0h,out_unitp,4)
          CALL Write_Mat(d0k,out_unitp,4)
        END IF

        CALL calc_freq_block(nb_inact21,d0h,d0k,d0ehess,                &
                             d0c,d0c_inv,norme,RPHTransfo%C_ini,        &
                             RPHTransfo%diabatic_freq,RPHTransfo%Qinact2n_sym)

        !CALL calc_freq(nb_inact21,d0h,d0k,d0ehess,d0c,d0c_inv,norme,    &
        !               RPHTransfo%C_ini,RPHTransfo%diabatic_freq)

      ELSE
        CALL calc_freq(nb_inact21,d0h,d0k,d0ehess,d0c,d0c_inv,norme,    &
                       RPHTransfo%C_ini,RPHTransfo%diabatic_freq)

      END IF

      CALL dealloc_NParray(d0h,"d0h",name_sub)
      CALL dealloc_NParray(d0k,"d0k",name_sub)

!-----------------------------------------------------------------

!-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'norm: ',norme
        write(out_unitp,*) 'freq: ',d0ehess(:)*auTOcm_inv
        write(out_unitp,*) 'd0c : '
        CALL Write_Mat(d0c,out_unitp,4)
        write(out_unitp,*) 'END ',name_sub
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      END SUBROUTINE sub_freq2_RPH
      SUBROUTINE sub_freq2_RPH_v2(RPHpara_AT_Qact1,pot0_corgrad,        &
                                  para_Tnum,mole,RPHTransfo,cHAC)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      USE CurviRPH_mod
      IMPLICIT NONE

      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Type_RPHpara_AT_Qact1), intent(inout) :: RPHpara_AT_Qact1
      real (kind=Rkind),            intent(inout) :: pot0_corgrad
      TYPE (Tnum)                                 :: para_Tnum
      TYPE (CoordType),             intent(inout) :: mole
      TYPE (Type_RPHTransfo),       intent(inout) :: RPHTransfo
      logical,                      intent(in)    :: cHAC



!----- working variables ---------------------------------------------
      TYPE (CoordType)   :: mole_loc
      TYPE(Type_dnMat)   :: dnGG

       real (kind=Rkind) :: d0hess(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)

      logical       :: deriv,num
      integer       :: i,j,i_Qdyn,i_Qact,i_Q1,i_Q21,j_Q21,nderiv

      integer           :: nb_act1,nb_inact21
      real (kind=Rkind) :: Qdyn(mole%nb_var)
      real (kind=Rkind) :: Qact(mole%nb_var)

      real (kind=Rkind) :: d0g(RPHTransfo%nb_inact21)


      real (kind=Rkind) :: a,d0req
      real (kind=Rkind) :: auTOcm_inv

      real (kind=Rkind), allocatable ::                                 &
        d1req(:),d2req(:,:),d3req(:,:,:),                               &
        d1g(:,:),d2g(:,:,:),                                            &
        d0h(:,:),d1hess(:,:,:),d2hess(:,:,:,:),                         &
        d0k(:,:),                                                       &
        d0hess_inv(:,:),trav1(:)


!----- for debuging --------------------------------------------------
       integer :: err_mem,memory
       character (len=*), parameter :: name_sub = 'sub_freq2_RPH_v2'
       logical, parameter :: debug = .FALSE.
       !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
       IF (debug) THEN
         write(out_unitp,*) 'BEGINNING ',name_sub
         CALL flush_perso(out_unitp)
       END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      nb_act1    = RPHTransfo%nb_act1
      nb_inact21 = RPHTransfo%nb_inact21
      IF (debug) write(out_unitp,*) 'nb_act1,nb_inact21',nb_act1,nb_inact21

      IF (.NOT. associated(RPHTransfo%C_ini)) THEN
        CALL alloc_array(RPHTransfo%C_ini,(/nb_inact21,nb_inact21/),    &
                          "RPHTransfo%C_ini",name_sub)
        RPHTransfo%C_ini(:,:) = ZERO
      END IF
      IF (debug) THEN
        write(out_unitp,*) 'RPHTransfo%C_ini'
        CALL Write_Mat(RPHTransfo%C_ini,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF



!-----------------------------------------------------------------
!--------- First Qact from RPHpara_AT_Qact1 ----------------------
      Qact(:) = ZERO
      i_Q1 = 0
      DO i_Qact=1,RPHTransfo%nb_var
        IF (RPHTransfo%list_act_OF_Qdyn(i_Qact) /= 1) CYCLE
        i_Q1 = i_Q1 + 1
        Qact(i_Qact) = RPHpara_AT_Qact1%RPHQact1(i_Q1)
      END DO
      IF (debug) write(out_unitp,*) 'Qact',Qact

!-----------------------------------------------------------------

!-----------------------------------------------------------------
!--------- Qact => Qdyn ------------------------------------------
! we need Qdyn because, we calculate, the hessian, grandient with Qdyn coord
!-----------------------------------------------------------------
       CALL Qact_TO_Qdyn_FROM_ActiveTransfo(Qact,Qdyn,mole%ActiveTransfo)
       IF (debug) write(out_unitp,*) 'Qdyn',Qdyn

!-----------------------------------------------------------------


!-----------------------------------------------------------------
!-----------------------------------------------------------------
!----- d0Qeq, d0g and d0h at Qdyn --------------------------------
!      Qdyn and Qact are also modified
!-----------------------------------------------------------------
      !For RPH, mole is not correct to get d0req ... from d0d1d2d3_Qeq (wrong nb_act1)
      ! It is OK for cHAC=.true. (coord_type=21)
      mole_loc            = mole
      IF (.NOT. cHAC) THEN
        mole_loc%nb_act1    = nb_act1    ! from RPH
        mole_loc%nb_inact21 = nb_inact21 ! from RPH
        mole_loc%nb_inact2n = nb_inact21 ! from RPH
        mole_loc%ActiveTransfo%list_act_OF_Qdyn(:) = RPHTransfo%list_act_OF_Qdyn ! from RPH
        mole_loc%ActiveTransfo%list_QactTOQdyn(:)  = RPHTransfo%list_QactTOQdyn  ! from RPH
        mole_loc%ActiveTransfo%list_QdynTOQact(:)  = RPHTransfo%list_QdynTOQact  ! from RPH
      END IF

      nderiv = 0
      deriv  = .FALSE.

      CALL alloc_NParray(d1req,(/ nb_act1 /),"d1req",name_sub)
      CALL alloc_NParray(d2req,(/ nb_act1,nb_act1 /),"d2req",name_sub)
      CALL alloc_NParray(d3req,(/ nb_act1,nb_act1,nb_act1 /),"d3req",name_sub)

      i_Q21 = 0
      DO i_Qdyn=1,RPHTransfo%nb_var
        IF (RPHTransfo%list_act_OF_Qdyn(i_Qdyn) /= 21) CYCLE

        CALL d0d1d2d3_Qeq(i_Qdyn,d0req,d1req,d2req,d3req,Qdyn,mole_loc,nderiv)

        IF (debug) write(out_unitp,*) 'i_Qdyn,i,d0req',i_Qdyn,i,d0req
        CALL flush_perso(out_unitp)
        i_Q21 = i_Q21 + 1
        i_Qact = RPHTransfo%list_QdynTOQact(i_Qdyn)

        RPHpara_AT_Qact1%dnQopt%d0(i_Q21) = d0req
        Qdyn(i_Qdyn)                      = d0req
        Qact(i_Qact)                      = d0req

      END DO
      RPHpara_AT_Qact1%init_done = 1 ! all dnQopt are done

      CALL dealloc_NParray(d1req,"d1req",name_sub)
      CALL dealloc_NParray(d2req,"d2req",name_sub)
      CALL dealloc_NParray(d3req,"d3req",name_sub)

      !------ The gradient ----------------------------------
      CALL alloc_NParray(d1g,(/ nb_inact21,nb_act1 /),"d1g",name_sub)
      CALL alloc_NParray(d2g,(/ nb_inact21,nb_act1,nb_act1 /),"d2g",name_sub)

      CALL d0d1d2_g(d0g,d1g,d2g,Qdyn,mole_loc,.FALSE.,.FALSE.,RPHTransfo%step)
      !IF (debug) CALL Write_Vec(d0g,out_unitp,4)
      RPHpara_AT_Qact1%dnGrad%d0(:) = d0g

      CALL dealloc_NParray(d1g,"d1g",name_sub)
      CALL dealloc_NParray(d2g,"d2g",name_sub)

      !------ The hessian ----------------------------------
      CALL alloc_NParray(d1hess,(/ nb_inact21,nb_inact21,nb_act1 /),    &
                        "d1hess",name_sub)
      CALL alloc_NParray(d2hess,(/nb_inact21,nb_inact21,nb_act1,nb_act1/),&
                        "d2hess",name_sub)

      CALL d0d1d2_h(d0hess,d1hess,d2hess,Qdyn,mole_loc,.FALSE.,.FALSE.,RPHTransfo%step)
      !IF (debug) CALL Write_Mat(d0hess,out_unitp,4)

      RPHpara_AT_Qact1%dnHess%d0(:,:) = d0hess

      CALL dealloc_NParray(d1hess,"d1hess",name_sub)
      CALL dealloc_NParray(d2hess,"d2hess",name_sub)

      IF (.NOT. mole%CurviRPH%init .AND. mole_loc%CurviRPH%init) THEN
        CALL CurviRPH1_TO_CurviRPH2(mole_loc%CurviRPH,mole%CurviRPH)
      END IF

      !-----------------------------------------------------------------
      !- the gardient is taken into account for d0Qeq -------------
      CALL alloc_NParray(d0h,(/nb_inact21,nb_inact21/),"d0h",name_sub)
      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%gradTOpot0) THEN
        CALL alloc_NParray(d0hess_inv,(/nb_inact21,nb_inact21/),"d0hess_inv",name_sub)
        CALL alloc_NParray(trav1,(/nb_inact21/),"trav1",name_sub)

        CALL inv_m1_TO_m2(d0h,d0hess_inv,nb_inact21,0,ZERO) ! not SVD
        trav1(:)     = matmul(d0hess_inv,d0g)
        pot0_corgrad = -HALF*dot_product(d0g,trav1)
        d0g(:)       = ZERO

        RPHpara_AT_Qact1%dnQopt%d0(:) = RPHpara_AT_Qact1%dnQopt%d0(:) - trav1(:)
        RPHpara_AT_Qact1%dnGrad%d0(:) = ZERO


        CALL dealloc_NParray(d0hess_inv,"d0hess_inv",name_sub)
        CALL dealloc_NParray(trav1,"trav1",name_sub)
      ELSE
        pot0_corgrad = ZERO
      END IF

      CALL dealloc_CoordType(mole_loc)

      !-----------------------------------------------------------------
      !------ The kinetic part -------------------------------
      CALL alloc_NParray(d0k,(/nb_inact21,nb_inact21/),"d0k",name_sub)

      CALL alloc_dnSVM(dnGG,mole%ndimG,mole%ndimG,mole%nb_act,0)

      CALL get_dng_dnGG(Qact,para_Tnum,mole,dnGG=dnGG,nderiv=0)
      !IF (debug) CALL Write_Mat(dnGG%d0,out_unitp,4)

      i_Q21 = 0
      DO i=1,RPHTransfo%nb_var
        IF (RPHTransfo%list_act_OF_Qdyn(i) /= 21) CYCLE
        i_Q21 = i_Q21 + 1
        j_Q21 = 0
        DO j=1,RPHTransfo%nb_var
          IF (RPHTransfo%list_act_OF_Qdyn(j) /= 21) CYCLE
          j_Q21 = j_Q21 + 1
          d0k(i_Q21,j_Q21) = dnGG%d0(i,j)
        END DO
      END DO
      !IF (debug) CALL Write_Mat(d0k,out_unitp,4)

      CALL dealloc_dnSVM(dnGG)

!-----------------------------------------------------------------
!     --- frequencies and normal modes calculation ....
      IF (debug) THEN
        write(out_unitp,*) 'd0hess,d0k'
        CALL Write_Mat(d0hess,out_unitp,4)
        CALL Write_Mat(d0k,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF

      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%purify_hess .OR. RPHTransfo%eq_hess) THEN
        CALL H0_symmetrization(d0h,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        CALL H0_symmetrization(d0k,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        IF (debug) THEN
          write(out_unitp,*) 'sym : d0hess,d0k'
          CALL Write_Mat(d0h,out_unitp,4)
          CALL Write_Mat(d0k,out_unitp,4)
        END IF

        CALL calc_freq_block(nb_inact21,d0h,d0k,                        &
                             RPHpara_AT_Qact1%dneHess%d0,               &
                             RPHpara_AT_Qact1%dnC%d0,                   &
                             RPHpara_AT_Qact1%dnC_inv%d0,               &
                             RPHpara_AT_Qact1%dnLnN%d0,                 &
                             RPHTransfo%C_ini,                          &
                             RPHTransfo%diabatic_freq,RPHTransfo%Qinact2n_sym)

        !CALL calc_freq(nb_inact21,d0h,d0k,d0ehess,d0c,d0c_inv,norme,    &
        !               RPHTransfo%C_ini,RPHTransfo%diabatic_freq)

      ELSE
        CALL calc_freq(nb_inact21,d0h,d0k,                        &
                       RPHpara_AT_Qact1%dneHess%d0,               &
                       RPHpara_AT_Qact1%dnC%d0,                   &
                       RPHpara_AT_Qact1%dnC_inv%d0,               &
                       RPHpara_AT_Qact1%dnLnN%d0,                 &
                       RPHTransfo%C_ini,                          &
                       RPHTransfo%diabatic_freq)

      END IF

      CALL dealloc_NParray(d0h,"d0h",name_sub)
      CALL dealloc_NParray(d0k,"d0k",name_sub)

!-----------------------------------------------------------------

!-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'dnLnN%d0 : ',RPHpara_AT_Qact1%dnLnN%d0
        write(out_unitp,*) 'freq :     ',RPHpara_AT_Qact1%dneHess%d0(:)*auTOcm_inv
        write(out_unitp,*) 'dnC%d0 :'
        CALL Write_Mat(RPHpara_AT_Qact1%dnC%d0,out_unitp,4)
        write(out_unitp,*) 'END ',name_sub
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      END SUBROUTINE sub_freq2_RPH_v2
      SUBROUTINE sub_dnfreq_4p_cHAC(dnQeq,dnC,dnLnN,dnEHess,dnHess,     &
                                    dnGrad,dnC_inv,pot0_corgrad,Qact,   &
                               para_Tnum,mole,RPHTransfo,nderiv,test)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE

!----- for the CoordType and Tnum --------------------------------------
      TYPE (Tnum)             :: para_Tnum
      TYPE (CoordType)          :: mole
      TYPE (Type_RPHTransfo)  :: RPHTransfo

      real (kind=Rkind), intent(inout) :: Qact(:)

!----- variables for the active and inactive namelists ----------------

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
      integer :: nderiv

!------ for the frequencies -------------------------------
      TYPE (Type_dnMat)     :: dnC,dnC_inv      ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnQeq            ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnEHess          ! derivative with respect to Qact1
      TYPE (Type_dnVec)     :: dnGrad           ! derivative with respect to Qact1
      TYPE (Type_dnMat)     :: dnHess           ! derivative with respect to Qact1
      TYPE (Type_dnS)       :: dnLnN            ! derivative with respect to Qact1

      real (kind=Rkind) :: pot0_corgrad,pot0_corgrad2

      real (kind=Rkind)  :: Qact1(RPHTransfo%nb_act1)


!----- pour les derivees ---------------------------------------------
      real (kind=Rkind) ::    step,step2,stepp,step24
      real (kind=Rkind) ::    d1


!----- for testing ---------------------------------------------------
      logical :: test


!----- working variables ---------------------------------------------
      integer           :: i,j,k,nb_inact21,nb_act1
      real (kind=Rkind) :: vi,vj

      real (kind=Rkind) ::  mat0(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat1(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  mat2(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec1(RPHTransfo%nb_inact21),vec0(RPHTransfo%nb_inact21)
      real (kind=Rkind) ::  vec2(RPHTransfo%nb_inact21)

      real (kind=Rkind) ::  auTOcm_inv

!----- for debuging --------------------------------------------------
      integer :: err_mem,memory
      character (len=*), parameter :: name_sub='sub_dnfreq_4p_cHAC'
      logical, parameter :: debug = .FALSE.
      !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'BEGINNING ',name_sub
        write(out_unitp,*) 'Qact',Qact
        write(out_unitp,*) 'purify_hess,eq_hess',                       &
                              RPHTransfo%purify_hess,RPHTransfo%eq_hess
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      step     = RPHTransfo%step
      step2    = ONE/(step*step)
      step24   = step2*HALF*HALF
      stepp    = ONE/(step+step)

      nb_inact21 = RPHTransfo%nb_inact21
      nb_act1    = RPHTransfo%nb_act1

      IF (RPHTransfo%step <= ZERO) THEN
        write(out_unitp,*) ' ERROR : RPHTransfo%step is <= to zero'
        STOP
      END IF


      CALL check_alloc_dnMat(dnC,'dnC',name_sub)
      CALL check_alloc_dnMat(dnC_inv,'dnC_inv',name_sub)
      CALL check_alloc_dnVec(dnQeq,'dnQeq',name_sub)
      CALL check_alloc_dnVec(dnEHess,'dnEHess',name_sub)
      CALL check_alloc_dnMat(dnHess,'dnHess',name_sub)
      CALL check_alloc_dnVec(dnGrad,'dnGrad',name_sub)
      CALL check_alloc_dnS(dnLnN,'dnLnN',name_sub)


      IF (nderiv == 0) THEN
        CALL sub_freq2_cHAC(dnEHess%d0,dnC%d0,dnC_inv%d0,                &
                           dnLnN%d0,dnHess%d0,dnQeq%d0,                 &
                           dnGrad%d0,pot0_corgrad,                      &
                           Qact,para_Tnum,mole,RPHTransfo)

        IF (debug) THEN
          write(out_unitp,*) 'dnQeq%d0',dnQeq%d0(:)
          write(out_unitp,*) 'freq',dnEHess%d0(:)*auTOcm_inv
          write(out_unitp,*) 'dnC'
          CALL Write_dnMat(dnC)
          write(out_unitp,*) 'dnHess'
          CALL Write_dnMat(dnHess)
          write(out_unitp,*) 'END ',name_sub
        END IF
        RETURN
      END IF


!-----------------------------------------------------------------
!----- frequencies calculation at Qact --------------------------
!-----------------------------------------------------------------

      CALL sub_freq2_cHAC(dnEHess%d0,dnC%d0,dnC_inv%d0,                  &
                         dnLnN%d0,dnHess%d0,dnQeq%d0,dnGrad%d0,         &
                         pot0_corgrad,Qact,para_Tnum,mole,RPHTransfo)

!-----------------------------------------------------------------
!----- end frequencies calculation at Qact ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d/Qqi et d2/dQi2 of frequencies ---------------------------
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1

        vi = Qact(i)

!       -- frequencies calculation at Qact(i)+step -------------
        Qact(i) = vi + step

        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d1(:,:,i)   = mat2
        dnC_inv%d2(:,:,i,i) = mat2

        dnLnN%d1(i)         = d1
        dnLnN%d2(i,i)       = d1

        dnC%d1(:,:,i)       = mat1(:,:)
        dnC%d2(:,:,i,i)     = mat1(:,:)

        dnHess%d1(:,:,i)    = mat0(:,:)
        dnHess%d2(:,:,i,i)  = mat0(:,:)

        dnQeq%d1(:,i)       = vec0(:)
        dnQeq%d2(:,i,i)     = vec0(:)

!       -- frequencies calculation at Qact(i)-step -------------
        Qact(i) = vi - step

        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d1(:,:,i)   = (dnC_inv%d1(:,:,i)   - mat2)*stepp
        dnC_inv%d2(:,:,i,i) = (dnC_inv%d2(:,:,i,i) + mat2 -TWO*dnC_inv%d0)*step2

        dnLnN%d1(i)        = (dnLnN%d1(i)   - d1)*stepp
        dnLnN%d2(i,i)      = (dnLnN%d2(i,i) + d1 -dnLnN%d0-dnLnN%d0)*step2

        dnC%d1(:,:,i)      = ( dnC%d1(:,:,i) -  mat1(:,:) ) * stepp
        dnC%d2(:,:,i,i)    = (dnC%d2(:,:,i,i)+mat1(:,:)-dnC%d0(:,:)-dnC%d0(:,:))*step2

        dnHess%d1(:,:,i)   = ( dnHess%d1(:,:,i) -  mat0(:,:) ) * stepp
        dnHess%d2(:,:,i,i) = (dnHess%d2(:,:,i,i)+mat0(:,:)-               &
                                   dnHess%d0(:,:)-dnHess%d0(:,:))*step2

        dnQeq%d1(:,i)      = ( dnQeq%d1(:,i) - vec0(:) ) * stepp
        dnQeq%d2(:,i,i)    = (dnQeq%d2(:,i,i)+vec0(:)-dnQeq%d0(:)-dnQeq%d0(:))*step2


        Qact(i) = vi
      END DO


!-----------------------------------------------------------------
!----- end d/Qqi and d2/dQi2 of frequencies ----------------------
!-----------------------------------------------------------------

!-----------------------------------------------------------------
!----- d2/dQidQj of frequencies (4 points) -----------------------
!      d2/dQidQj = ( v(Qi+,Qj+)+v(Qi-,Qj-)-v(Qi-,Qj+)-v(Qi+,Qj-) )/(4*s*s)
!-----------------------------------------------------------------
      DO i=1,RPHTransfo%nb_act1
      DO j=i+1,RPHTransfo%nb_act1

        vi = Qact(i)
        vj = Qact(j)


!       -- frequencies calculation at Qact(i)+step Qact(j)+step
        Qact(i) = vi + step
        Qact(j) = vj + step
        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = mat2
        dnLnN%d2(i,j)       = d1
        dnC%d2(:,:,i,j)     = mat1(:,:)
        dnHess%d2(:,:,i,j)  = mat0(:,:)
        dnQeq%d2(:,i,j)     = vec0(:)

!       -- frequencies calculation at Qact(i)-step Qact(j)-step
        Qact(i) = vi - step
        Qact(j) = vj - step

        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) + mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       + d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     + mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  + mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     + vec0

!       -- frequencies calculation at Qact(i)-step Qact(j)+step
        Qact(i) = vi - step
        Qact(j) = vj + step

        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) - mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       - d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     - mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  - mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     - vec0

!       -- frequencies calculation at Qact(i)+step Qact(j)-step
        Qact(i) = vi + step
        Qact(j) = vj - step

        CALL sub_freq2_cHAC(vec1,mat1,mat2,d1,mat0,vec0,vec2,    &
                       pot0_corgrad2,Qact,para_Tnum,mole,RPHTransfo)

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) - mat2
        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       - d1
        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     - mat1
        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  - mat0
        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     - vec0


!       -- d2/dQi/dQj -----------------------------------------

        dnC_inv%d2(:,:,i,j) = dnC_inv%d2(:,:,i,j) * step24
        dnC_inv%d2(:,:,j,i) = dnC_inv%d2(:,:,i,j)

        dnLnN%d2(i,j)       = dnLnN%d2(i,j)       * step24
        dnLnN%d2(j,i)       = dnLnN%d2(i,j)

        dnC%d2(:,:,i,j)     = dnC%d2(:,:,i,j)     * step24
        dnC%d2(:,:,j,i)     = dnC%d2(:,:,i,j)

        dnHess%d2(:,:,i,j)  = dnHess%d2(:,:,i,j)  * step24
        dnHess%d2(:,:,j,i)  = dnHess%d2(:,:,i,j)

        dnQeq%d2(:,i,j)     = dnQeq%d2(:,i,j)     * step24
        dnQeq%d2(:,j,i)     = dnQeq%d2(:,i,j)


        Qact(i) = vi
        Qact(j) = vj
      END DO
      END DO
!-----------------------------------------------------------------
!----- end d2/dQidQj of frequencies ------------------------------
!-----------------------------------------------------------------


      DO i=1,RPHTransfo%nb_act1
        dnLnN%d1(i) = dnLnN%d1(i)/dnLnN%d0
      END DO
      DO i=1,RPHTransfo%nb_act1
      DO j=1,RPHTransfo%nb_act1
        dnLnN%d2(i,j) = dnLnN%d2(i,j)/dnLnN%d0 - dnLnN%d1(i)*dnLnN%d1(j)
      END DO
      END DO

!-----------------------------------------------------------
      IF (print_level >= 1) THEN
        IF (maxval(abs(dnEHess%d0)) > 9000._Rkind) THEN
          write(out_unitp,*) ' frequencies : ',Qact(1:RPHTransfo%nb_act1), &
                                                dnEHess%d0(:)*auTOcm_inv
        ELSE
          write(out_unitp,11) Qact(1:RPHTransfo%nb_act1),               &
                                                dnEHess%d0(:)*auTOcm_inv
 11       format(' frequencies : ',30f10.4)
        END IF
      END IF
       IF (debug .OR. test) THEN
         write(out_unitp,*) 'dnQeq'
         CALL Write_dnVec(dnQeq)
         write(out_unitp,*) 'dnHess'
         CALL Write_dnMat(dnHess)
         write(out_unitp,*) 'dnC_inv'
         CALL Write_dnMat(dnC_inv)

         write(out_unitp,*) 'dnC'
         CALL Write_dnMat(dnC)
         write(out_unitp,*) 'dnLnN'
         CALL Write_dnS(dnLnN)

       END IF

       IF (debug) THEN
         write(out_unitp,*) 'END ',name_sub
       END IF
      CALL flush_perso(out_unitp)
!-----------------------------------------------------------

      END SUBROUTINE sub_dnfreq_4p_cHAC
      SUBROUTINE sub_freq2_cHAC(d0ehess,d0c,d0c_inv,                    &
                               norme,d0hess,d0Qeq,d0g,pot0_corgrad,     &
                               Qact,para_Tnum,mole,RPHTransfo)
      USE mod_system
      USE mod_dnSVM
      USE mod_Constant, only : get_Conv_au_TO_unit
      USE mod_Coord_KEO
      IMPLICIT NONE

      !----- for the CoordType and Tnum --------------------------------------
      TYPE (Tnum)        :: para_Tnum
      TYPE (CoordType)   :: mole

      real (kind=Rkind), intent(inout) :: Qact(:)

      real (kind=Rkind)  :: rho,vep

!----- variables for the active and inactive namelists ----------------
      TYPE (Type_RPHTransfo)  :: RPHTransfo

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------



!------ pour les frequences -------------------------------

       real (kind=Rkind) :: d0ehess(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0ek(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0g(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0Qeq(RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0hess(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0c(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: d0c_inv(RPHTransfo%nb_inact21,RPHTransfo%nb_inact21)
       real (kind=Rkind) :: norme

       real (kind=Rkind) :: pot0_corgrad


!----- working variables ---------------------------------------------
!----- variables pour les derivees -----------------------------------
      logical       :: deriv,num
      integer       :: i,j,i_Qdyn,nderiv
      logical       :: special

      integer       :: nb_act1,nb_inact21
      real (kind=Rkind) :: Qdyn(mole%nb_var)


      real (kind=Rkind) :: a,d0req
      real (kind=Rkind) :: auTOcm_inv

      real (kind=Rkind), allocatable ::                                 &
        d1req(:),d2req(:,:),d3req(:,:,:),                               &
        d1g(:,:),d2g(:,:,:),                                            &
        d0h(:,:),d1hess(:,:,:),d2hess(:,:,:,:),                         &
        d0k(:,:),                                                       &
        d0hess_inv(:,:),trav1(:)

      TYPE(Type_dnMat) :: dnGG

!----- for debuging --------------------------------------------------
       integer :: err_mem,memory
       character (len=*), parameter :: name_sub = 'sub_freq2_cHAC'
       logical, parameter :: debug = .FALSE.
       !logical, parameter :: debug = .TRUE.
!-----------------------------------------------------------
       IF (debug) THEN
         write(out_unitp,*) 'BEGINNING ',name_sub
         write(out_unitp,*) 'Qact',Qact
         write(out_unitp,*) 'RPHTransfo%step',RPHTransfo%step
         CALL flush_perso(out_unitp)
       END IF
!-----------------------------------------------------------
      auTOcm_inv = get_Conv_au_TO_unit('E','cm-1')

      nb_act1    = RPHTransfo%nb_act1
      nb_inact21 = RPHTransfo%nb_inact21
      IF (.NOT. associated(RPHTransfo%C_ini)) THEN
        CALL alloc_array(RPHTransfo%C_ini,(/nb_inact21,nb_inact21/),    &
                          "RPHTransfo%C_ini",name_sub)
        RPHTransfo%C_ini(:,:) = ZERO
      END IF
      IF (debug) THEN
        write(out_unitp,*) 'RPHTransfo%C_ini'
        CALL Write_Mat(RPHTransfo%C_ini,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF

!-----------------------------------------------------------------
!--------- Qact => Qdyn ------------------------------------------
! we need Qdyn because, we calculate, the hessian, grandient with Qdyn coord
!-----------------------------------------------------------------
       CALL Qact_TO_Qdyn_FROM_ActiveTransfo(Qact,Qdyn,mole%ActiveTransfo)
       IF (debug) write(out_unitp,*) 'Qdyn',Qdyn

!-----------------------------------------------------------------


!-----------------------------------------------------------------
!-----------------------------------------------------------------
!----- d0Qeq, d0g and d0h at Qdyn --------------------------------
!      Qdyn and Qact are also modified
!-----------------------------------------------------------------
      nderiv = 0
      deriv  = .FALSE.

      CALL alloc_NParray(d1req,(/ nb_act1 /),"d1req",name_sub)
      CALL alloc_NParray(d2req,(/ nb_act1,nb_act1 /),"d2req",name_sub)
      CALL alloc_NParray(d3req,(/ nb_act1,nb_act1,nb_act1 /),"d3req",name_sub)

      DO i=1,nb_inact21

        i_Qdyn = mole%ActiveTransfo%list_QactTOQdyn(nb_act1+i)

        CALL d0d1d2d3_Qeq(i_Qdyn,d0req,d1req,d2req,d3req,Qdyn,mole,nderiv)

        IF (debug) write(out_unitp,*) 'i_Qdyn,i,d0req',i_Qdyn,i,d0req
        CALL flush_perso(out_unitp)
        d0Qeq(i)             = d0req
        Qdyn(i_Qdyn)         = d0req
        Qact(nb_act1+i)      = d0req

      END DO

      CALL dealloc_NParray(d1req,"d1req",name_sub)
      CALL dealloc_NParray(d2req,"d2req",name_sub)
      CALL dealloc_NParray(d3req,"d3req",name_sub)

      !------ The gradient ----------------------------------
      CALL alloc_NParray(d1g,(/ nb_inact21,nb_act1 /),"d1g",name_sub)
      CALL alloc_NParray(d2g,(/ nb_inact21,nb_act1,nb_act1 /),"d2g",name_sub)

      CALL d0d1d2_g(d0g,d1g,d2g,Qdyn,mole,.FALSE.,.FALSE.,RPHTransfo%step)

      CALL dealloc_NParray(d1g,"d1g",name_sub)
      CALL dealloc_NParray(d2g,"d2g",name_sub)

      !------ The hessian ----------------------------------
      CALL alloc_NParray(d1hess,(/ nb_inact21,nb_inact21,nb_act1 /),    &
                        "d1hess",name_sub)
      CALL alloc_NParray(d2hess,(/nb_inact21,nb_inact21,nb_act1,nb_act1/),&
                        "d2hess",name_sub)

      CALL d0d1d2_h(d0hess,d1hess,d2hess,Qdyn,mole,.FALSE.,.FALSE.,RPHTransfo%step)

      CALL dealloc_NParray(d1hess,"d1hess",name_sub)
      CALL dealloc_NParray(d2hess,"d2hess",name_sub)


      !-----------------------------------------------------------------
      !- the gardient is taken into account for d0Qeq -------------
      CALL alloc_NParray(d0h,(/nb_inact21,nb_inact21/),"d0h",name_sub)
      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%gradTOpot0) THEN
        CALL alloc_NParray(d0hess_inv,(/nb_inact21,nb_inact21/),"d0hess_inv",name_sub)
        CALL alloc_NParray(trav1,(/nb_inact21/),"trav1",name_sub)

        CALL inv_m1_TO_m2(d0h,d0hess_inv,nb_inact21,0,ZERO) ! not SVD
        trav1(:)     = matmul(d0hess_inv,d0g)
        pot0_corgrad = -HALF*dot_product(d0g,trav1)
        d0Qeq(:)     = d0Qeq(:) - trav1(:)
        d0g(:)       = ZERO

        !-- merge d0Qeq(:) with Qact(:)
        CALL Qinact2n_TO_Qact_FROM_ActiveTransfo(d0Qeq,Qact,mole%ActiveTransfo)

        CALL dealloc_NParray(d0hess_inv,"d0hess_inv",name_sub)
        CALL dealloc_NParray(trav1,"trav1",name_sub)
      ELSE
        pot0_corgrad = ZERO
      END IF

      !-----------------------------------------------------------------
      !------ The kinetic part -------------------------------
      CALL alloc_NParray(d0k,(/nb_inact21,nb_inact21/),"d0k",name_sub)

      CALL alloc_dnSVM(dnGG,mole%ndimG,mole%ndimG,mole%nb_act,0)

      CALL get_dng_dnGG(Qact,para_Tnum,mole,dnGG=dnGG,nderiv=0)

      d0k(:,:) = dnGG%d0(nb_act1+1:nb_act1+nb_inact21,                  &
                         nb_act1+1:nb_act1+nb_inact21)

      CALL dealloc_dnSVM(dnGG)


!-----------------------------------------------------------------
!     --- frequencies and normal modes calculation ....
      IF (debug) THEN
        write(out_unitp,*) 'd0hess,d0k'
        CALL Write_Mat(d0hess,out_unitp,4)
        CALL Write_Mat(d0k,out_unitp,4)
        CALL flush_perso(out_unitp)
      END IF

      d0h(:,:) = d0hess(:,:)

      IF (RPHTransfo%purify_hess .OR. RPHTransfo%eq_hess) THEN
        CALL H0_symmetrization(d0h,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        CALL H0_symmetrization(d0k,nb_inact21,                        &
                               RPHTransfo%Qinact2n_sym,               &
                               RPHTransfo%dim_equi,RPHTransfo%tab_equi)
        IF (debug) THEN
          write(out_unitp,*) 'sym : d0hess,d0k'
          CALL Write_Mat(d0h,out_unitp,4)
          CALL Write_Mat(d0k,out_unitp,4)
        END IF

        CALL calc_freq_block(nb_inact21,d0h,d0k,d0ehess,                &
                             d0c,d0c_inv,norme,RPHTransfo%C_ini,        &
                             RPHTransfo%diabatic_freq,RPHTransfo%Qinact2n_sym)

        !CALL calc_freq(nb_inact21,d0h,d0k,d0ehess,d0c,d0c_inv,norme,    &
        !               RPHTransfo%C_ini,RPHTransfo%diabatic_freq)

      ELSE
        CALL calc_freq(nb_inact21,d0h,d0k,d0ehess,d0c,d0c_inv,norme,    &
                       RPHTransfo%C_ini,RPHTransfo%diabatic_freq)

      END IF

      CALL dealloc_NParray(d0h,"d0h",name_sub)
      CALL dealloc_NParray(d0k,"d0k",name_sub)

!-----------------------------------------------------------------

!-----------------------------------------------------------
      IF (debug) THEN
        write(out_unitp,*) 'norm: ',norme
        write(out_unitp,*) 'freq : ',d0ehess(:)*auTOcm_inv
        write(out_unitp,*) 'd0c : '
        CALL Write_Mat(d0c,out_unitp,4)
        write(out_unitp,*) 'END ',name_sub
        CALL flush_perso(out_unitp)
      END IF
!-----------------------------------------------------------
      END SUBROUTINE sub_freq2_cHAC


   END MODULE mod_PrimOp_RPH

